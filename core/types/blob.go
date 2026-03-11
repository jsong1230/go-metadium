// Copyright 2024 The go-ethereum Authors
// This file is part of the go-ethereum library.
//
// The go-ethereum library is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// The go-ethereum library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.

package types

import (
	"github.com/ethereum/go-ethereum/common"
)

const (
	BlobSize = 4096 * 31 // 131072 bytes per blob
)

// BlobTxSidecar contains the blobs and proofs for a blob transaction.
type BlobTxSidecar struct {
	Blobs       [][]byte       // Blob data (4096 * 31 bytes each)
	Commitments [][]byte       // Blob commitments (KZG commitments)
	Proofs      [][]byte       // Blob proofs
	BlobHashes  []common.Hash  // Versioned hashes of blobs
}

// BlobTxSidecarSize returns the total size of the sidecars in bytes.
func (s *BlobTxSidecar) Size() int {
	size := 0
	for _, blob := range s.Blobs {
		size += len(blob)
	}
	for _, commitment := range s.Commitments {
		size += len(commitment)
	}
	for _, proof := range s.Proofs {
		size += len(proof)
	}
	size += len(s.BlobHashes) * 32
	return size
}
