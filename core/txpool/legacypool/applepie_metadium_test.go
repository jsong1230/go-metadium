// Copyright 2026 The go-metadium Authors
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

package legacypool

import (
	"crypto/ecdsa"
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
)

// applepieConfig returns a chain config whose Applepie fork sits at the given
// block, or is unset when block is nil.
func applepieConfig(block *big.Int) *params.ChainConfig {
	config := *params.TestChainConfig
	config.ApplepieBlock = block
	return &config
}

// feeDelegateTx builds a fully signed type-22 transaction: the sender signs the
// inner dynamic-fee transaction, then the fee payer signs the fee-payer hash.
// This is the same construction the mixed-tx end-to-end test performs over RPC.
func feeDelegateTx(t *testing.T, config *params.ChainConfig, nonce uint64, senderKey, feePayerKey *ecdsa.PrivateKey) *types.Transaction {
	t.Helper()

	to := common.Address{0x77}
	inner := types.DynamicFeeTx{
		ChainID:   config.ChainID,
		Nonce:     nonce,
		GasTipCap: big.NewInt(1),
		GasFeeCap: big.NewInt(1_000_000_000),
		Gas:       100_000,
		To:        &to,
		Value:     new(big.Int),
	}
	senderSigned, err := types.SignTx(types.NewTx(&inner), types.LatestSigner(config), senderKey)
	if err != nil {
		t.Fatalf("signing the sender transaction: %v", err)
	}
	v, r, s := senderSigned.RawSignatureValues()

	signedInner := inner
	signedInner.V, signedInner.R, signedInner.S = v, r, s
	feePayer := crypto.PubkeyToAddress(feePayerKey.PublicKey)

	tx, err := types.SignTx(types.NewTx(&types.FeeDelegateDynamicFeeTx{
		SenderTx: signedInner,
		FeePayer: &feePayer,
		FV:       new(big.Int),
		FR:       new(big.Int),
		FS:       new(big.Int),
	}), types.NewFeeDelegateSigner(config.ChainID), feePayerKey)
	if err != nil {
		t.Fatalf("signing as the fee payer: %v", err)
	}
	return tx
}

// TestPoolFeeDelegationFollowsApplepie pins the pool's Applepie gate.
//
// pool.feedelegation was hard-coded true at construction after the v1.13.14
// rebase — old master recomputed it per reset as IsApplepie(head+1) — so the
// pool admitted and propagated type-22 transactions on a chain where the fork is
// unset, and nodes running the pre-rebase code rejected them at execution
// (issue #71). The indicator is now derived from the head on every check.
func TestPoolFeeDelegationFollowsApplepie(t *testing.T) {
	feePayerKey, _ := crypto.GenerateKey()

	for _, tt := range []struct {
		name     string
		applepie *big.Int
		wantErr  error
	}{
		{"fork unset", nil, core.ErrTxTypeNotSupported},
		{"fork in the future", big.NewInt(1_000_000), core.ErrTxTypeNotSupported},
		{"fork active", big.NewInt(0), nil},
	} {
		t.Run(tt.name, func(t *testing.T) {
			config := applepieConfig(tt.applepie)
			pool, senderKey := setupPoolWithConfig(config)
			defer pool.Close()

			testAddBalance(pool, crypto.PubkeyToAddress(senderKey.PublicKey), big.NewInt(1e18))
			testAddBalance(pool, crypto.PubkeyToAddress(feePayerKey.PublicKey), big.NewInt(1e18))

			err := pool.addRemoteSync(feeDelegateTx(t, config, 0, senderKey, feePayerKey))
			if tt.wantErr == nil {
				if err != nil {
					t.Fatalf("type-22 rejected on an Applepie chain: %v", err)
				}
				return
			}
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("want %v, got %v", tt.wantErr, err)
			}
		})
	}
}
