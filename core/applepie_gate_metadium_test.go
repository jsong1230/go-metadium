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

package core

import (
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/rawdb"
	"github.com/ethereum/go-ethereum/core/state"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/params"
	"github.com/holiman/uint256"
)

// TestFeeDelegationRequiresApplepie pins the execution-side fork gate for
// Metadium's type-22 transactions.
//
// Fee delegation activates at Applepie. The v1.13.14 rebase dropped this check
// together with the pool's fork indicator, leaving ApplepieBlock with no
// consumers: a chain with the fork unset would execute a fee-delegated
// transaction that a node running the pre-rebase code rejects, and the two would
// split. Mainnet and testnet activated Applepie long ago, so the gate only
// changes behaviour where the fork is unset — which is exactly the case that
// could split (issue #71).
func TestFeeDelegationRequiresApplepie(t *testing.T) {
	var (
		sender   = common.HexToAddress("0x1111111111111111111111111111111111111111")
		feePayer = common.HexToAddress("0x2222222222222222222222222222222222222222")
		to       = common.HexToAddress("0x3333333333333333333333333333333333333333")
	)
	baseConfig := func() *params.ChainConfig {
		return &params.ChainConfig{
			ChainID:             big.NewInt(1337),
			HomesteadBlock:      big.NewInt(0),
			EIP150Block:         big.NewInt(0),
			EIP155Block:         big.NewInt(0),
			EIP158Block:         big.NewInt(0),
			ByzantiumBlock:      big.NewInt(0),
			ConstantinopleBlock: big.NewInt(0),
			PetersburgBlock:     big.NewInt(0),
			IstanbulBlock:       big.NewInt(0),
			MuirGlacierBlock:    big.NewInt(0),
			BerlinBlock:         big.NewInt(0),
			LondonBlock:         big.NewInt(0),
			Ethash:              new(params.EthashConfig),
		}
	}

	// apply runs one fee-delegated message against a fresh state.
	apply := func(config *params.ChainConfig, blockNumber int64) error {
		statedb, err := state.New(types.EmptyRootHash, state.NewDatabase(rawdb.NewMemoryDatabase()), nil)
		if err != nil {
			t.Fatalf("state: %v", err)
		}
		funds := uint256.NewInt(1e18)
		statedb.AddBalance(sender, funds)
		statedb.AddBalance(feePayer, funds)

		blockCtx := vm.BlockContext{
			CanTransfer: CanTransfer,
			Transfer:    Transfer,
			Coinbase:    common.Address{},
			BlockNumber: big.NewInt(blockNumber),
			Time:        1,
			Difficulty:  new(big.Int),
			GasLimit:    10_000_000,
			BaseFee:     new(big.Int),
		}
		msg := &Message{
			From:      sender,
			To:        &to,
			Nonce:     0,
			Value:     new(big.Int),
			GasLimit:  100_000,
			GasPrice:  big.NewInt(1),
			GasFeeCap: big.NewInt(1),
			GasTipCap: big.NewInt(1),
			FeePayer:  &feePayer,
			// The fee payer's signature is checked in TransactionToMessage, not
			// here; this test is about the fork gate only.
			SkipAccountChecks: true,
		}
		evm := vm.NewEVM(blockCtx, vm.TxContext{Origin: sender, GasPrice: msg.GasPrice}, statedb, config, vm.Config{})
		_, err = ApplyMessage(evm, msg, new(GasPool).AddGas(msg.GasLimit))
		return err
	}

	t.Run("fork unset", func(t *testing.T) {
		err := apply(baseConfig(), 1)
		if !errors.Is(err, ErrTxTypeNotSupported) {
			t.Fatalf("fee delegation executed on a chain without Applepie: %v", err)
		}
	})

	t.Run("fork in the future", func(t *testing.T) {
		config := baseConfig()
		config.ApplepieBlock = big.NewInt(100)
		if err := apply(config, 99); !errors.Is(err, ErrTxTypeNotSupported) {
			t.Fatalf("fee delegation executed one block before Applepie: %v", err)
		}
		if err := apply(config, 100); err != nil {
			t.Fatalf("fee delegation rejected at the activation block: %v", err)
		}
	})

	t.Run("fork active", func(t *testing.T) {
		config := baseConfig()
		config.ApplepieBlock = big.NewInt(0)
		if err := apply(config, 1); err != nil {
			t.Fatalf("fee delegation rejected on an Applepie chain: %v", err)
		}
	})
}
