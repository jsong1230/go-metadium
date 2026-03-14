// Copyright 2023 The go-ethereum Authors
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

// Package kzg4844 implements the KZG point evaluation for EIP-4844 blob transactions.
// It uses the pure-Go go-kzg-4844 library (github.com/crate-crypto/go-kzg-4844).
package kzg4844

import (
	"crypto/sha256"
	"errors"
	"sync"

	gokzg4844 "github.com/crate-crypto/go-kzg-4844"
)

const (
	// BlobCommitmentVersionKZG is the version byte for KZG commitments (per EIP-4844).
	BlobCommitmentVersionKZG uint8 = 0x01

	// FieldElementsPerBlob is the number of field elements in a blob (per EIP-4844).
	FieldElementsPerBlob = gokzg4844.ScalarsPerBlob
)

// BLSModulus is the BLS12-381 scalar field modulus as a 32-byte big-endian value.
var BLSModulus = gokzg4844.BlsModulus

var (
	// errInvalidCommitmentVersion is returned when the versioned hash has an unsupported version byte.
	errInvalidCommitmentVersion = errors.New("invalid commitment version")

	// errCommitmentMismatch is returned when the commitment doesn't match the versioned hash.
	errCommitmentMismatch = errors.New("commitment does not match versioned hash")

	// errKZGVerificationFailed is returned when KZG proof verification fails.
	errKZGVerificationFailed = errors.New("kzg proof verification failed")
)

// context is the global KZG context. Initialized once on first use.
var (
	kzgContext *gokzg4844.Context
	kzgOnce   sync.Once
	kzgErr    error
)

// getContext returns the singleton KZG context, initializing it on first call.
func getContext() (*gokzg4844.Context, error) {
	kzgOnce.Do(func() {
		kzgContext, kzgErr = gokzg4844.NewContext4096Secure()
	})
	return kzgContext, kzgErr
}

// KZGToVersionedHash computes the versioned hash of a KZG commitment.
// This implements kzg_to_versioned_hash from the EIP-4844 spec:
//
//	def kzg_to_versioned_hash(commitment: KZGCommitment) -> VersionedHash:
//	    return BLOB_COMMITMENT_VERSION_KZG + sha256(commitment)[1:]
func KZGToVersionedHash(commitment []byte) [32]byte {
	h := sha256.Sum256(commitment)
	h[0] = BlobCommitmentVersionKZG
	return h
}

// VerifyKZGProof verifies a KZG point evaluation proof per EIP-4844.
//
// Parameters (all in big-endian byte representation):
//   - versionedHash: 32-byte versioned hash of the commitment
//   - z:             32-byte evaluation point (field element)
//   - y:             32-byte claimed evaluation result (field element)
//   - commitment:    48-byte KZG commitment
//   - proof:         48-byte KZG proof
//
// Returns nil on success, or an error describing the failure.
func VerifyKZGProof(versionedHash [32]byte, z, y [32]byte, commitment, proof [48]byte) error {
	// 1. Validate the version byte of the versioned hash.
	if versionedHash[0] != BlobCommitmentVersionKZG {
		return errInvalidCommitmentVersion
	}

	// 2. Verify that the commitment matches the versioned hash.
	// kzg_to_versioned_hash(commitment) == versioned_hash
	computedHash := KZGToVersionedHash(commitment[:])
	if computedHash != versionedHash {
		return errCommitmentMismatch
	}

	// 3. Obtain the KZG context (loads trusted setup once).
	ctx, err := getContext()
	if err != nil {
		return err
	}

	// 4. Run verify_kzg_proof(commitment, z, y, proof).
	if err := ctx.VerifyKZGProof(
		gokzg4844.KZGCommitment(commitment),
		gokzg4844.Scalar(z),
		gokzg4844.Scalar(y),
		gokzg4844.KZGProof(proof),
	); err != nil {
		return errKZGVerificationFailed
	}

	return nil
}
