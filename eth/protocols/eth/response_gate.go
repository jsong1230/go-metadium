// Copyright 2026 The go-metadium Authors
// This file is part of the go-metadium library.
//
// The go-metadium library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-metadium library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-metadium library. If not, see <http://www.gnu.org/licenses/>.

package eth

import (
	"fmt"

	"github.com/ethereum/go-ethereum/rlp"
)

// This file keeps a response from being decoded before we know we asked for it.
//
// Every response message on this protocol is `[request-id, payload]`. The
// handlers used to decode the whole thing and only then hand it to the
// dispatcher, which is where the request id is matched against the in-flight
// requests. A peer that never received a request from us could therefore make
// us expand an arbitrary payload — bounded in wire size by maxMessageSize, but
// not in the size of the Go values it decodes into, which is the amplification
// that makes it worth anything to an attacker.
//
// The gate below is the same property upstream go-ethereum adopted in
// "eth/protocols/eth, eth/protocols/snap: delayed p2p message decoding"
// (0cba803fb, v1.17.0, CVE-2026-26313): confirm the response belongs to an
// active request first, decode second. Upstream's version reaches further —
// it also defers decoding until the response is checked against the request's
// limits, and it restructured p2p/tracker into a per-peer instance to do it.
// That rework sits on the eth/69-72 protocol layout and does not transplant
// onto this tree; what is here is the part that closes the unsolicited-message
// path, applied to the dispatcher this fork actually runs.
//
// The gate is keyed on the pair (response code, request id), not on the id
// alone. Keying on the id alone left one gap: a peer holding any live id could
// answer it with a different message code and still get past the gate, which
// let it choose the cheapest shape to expand rather than the one it was asked
// for. Such a response was caught afterwards — the dispatcher reports
// errMismatchingResponseType and the peer is dropped — but only after the
// decode the gate exists to prevent.
//
// The outcome for each case is unchanged; only the decode is now skipped:
//
//   - id not tracked at all: dropped silently, as the dispatcher's
//     errDanglingResponse path did;
//   - id tracked for a different code: the peer is dropped, as
//     errMismatchingResponseType did.

// maxPendingIDs bounds the gate's index. Not every request path can untrack its
// id: the dispatcher-managed ones (headers, bodies, receipts) are removed
// exactly, but pooled transactions and blob sidecars are sent straight to the
// wire and are only untracked when an answer arrives, so an unanswered request
// would otherwise sit in the index for the life of the connection.
//
// The bound is a ring: inserting past capacity evicts the oldest id. Real
// concurrency per peer is a handful of requests (the dispatcher's in-flight
// set, one pooled-transaction retrieval, one serial blob fetch), so eviction
// only ever reaches ids that have long since gone unanswered. Evicting a live
// id would drop a legitimate response, which is why the capacity is far above
// what the request paths can produce.
const maxPendingIDs = 256

// responseEnvelope decodes the request id of a response message while leaving
// the payload as raw RLP. The payload is decoded separately, and only once the
// gate has passed.
type responseEnvelope struct {
	RequestId uint64
	Payload   rlp.RawValue
}

// trackPending records that a request id was sent to this peer, together with
// the response code that id authorises.
//
// Registration happens before the request is written to the wire, so a peer
// that answers immediately cannot have its response gated out by an index that
// has not caught up yet. The index may therefore hold an id whose send
// subsequently failed; that is the harmless direction, and untrackPending
// cleans it up.
func (p *Peer) trackPending(want, id uint64) {
	p.pendingLock.Lock()
	defer p.pendingLock.Unlock()

	if _, ok := p.pendingIDs[id]; ok {
		return
	}
	// Reclaim the slot this insert is about to take, once the ring has wrapped.
	// Counting the slots written so far is what tells an unused slot from a
	// real entry: id 0 is a value rand.Uint64 can return, so a zero in the ring
	// cannot serve as the "empty" marker. The id found in a reclaimed slot may
	// already have been untracked, in which case the delete is a no-op.
	if p.pendingFilled == len(p.pendingRing) {
		delete(p.pendingIDs, p.pendingRing[p.pendingPos])
	} else {
		p.pendingFilled++
	}
	p.pendingRing[p.pendingPos] = id
	p.pendingPos = (p.pendingPos + 1) % len(p.pendingRing)
	p.pendingIDs[id] = want
}

// untrackPending forgets an in-flight request id.
func (p *Peer) untrackPending(id uint64) {
	p.pendingLock.Lock()
	defer p.pendingLock.Unlock()
	delete(p.pendingIDs, id)
}

// gateResponse checks a response's (code, id) pair against the requests this
// peer was sent, before the payload is decoded.
//
// It reports whether the caller should stop. (true, nil) is an unsolicited
// response, dropped without being decoded — the silent treatment the
// dispatcher's errDanglingResponse path already gave it. A non-nil error is a
// response answering a live id with the wrong message code, which is the case
// errMismatchingResponseType covered after decoding; returning it here drops
// the peer just the same, one decode earlier.
func (p *Peer) gateResponse(code, id uint64) (bool, error) {
	p.pendingLock.RLock()
	want, ok := p.pendingIDs[id]
	p.pendingLock.RUnlock()

	switch {
	case !ok:
		p.dropUnsolicited(code, id)
		return true, nil
	case want != code:
		return false, fmt.Errorf("%w: message %d for request %d, want %d", errMismatchingResponseType, code, id, want)
	default:
		return false, nil
	}
}

// dropUnsolicited reports the response as dangling and tells the caller to stop
// processing it. Dropping such a response silently is the pre-existing
// behaviour: the dispatcher answered an untracked id with errDanglingResponse,
// which dispatchResponse turned into a nil return. The tracker is still told,
// so the dangling-response metrics keep counting what they used to count.
//
// The log is at debug level rather than the warning the syncer used to emit:
// reaching this line takes nothing but an unauthenticated peer sending a
// message, so a warning here is a log-flooding primitive.
func (p *Peer) dropUnsolicited(code, id uint64) {
	p.Log().Debug("Dropping unsolicited response", "code", code, "reqid", id)
	requestTracker.Fulfil(p.id, p.version, code, id)
}
