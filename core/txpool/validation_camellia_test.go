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

package txpool

import (
	"errors"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/params"
)

// camelliaOnlyChainConfig is a chain that runs the Shanghai and Cancun rules
// through CamelliaBlock rather than through timestamps, which is what mainnet
// and testnet do.
func camelliaOnlyChainConfig() *params.ChainConfig {
	return &params.ChainConfig{
		ChainID:                       big.NewInt(1337),
		HomesteadBlock:                big.NewInt(0),
		EIP150Block:                   big.NewInt(0),
		EIP155Block:                   big.NewInt(0),
		EIP158Block:                   big.NewInt(0),
		ByzantiumBlock:                big.NewInt(0),
		ConstantinopleBlock:           big.NewInt(0),
		PetersburgBlock:               big.NewInt(0),
		IstanbulBlock:                 big.NewInt(0),
		MuirGlacierBlock:              big.NewInt(0),
		BerlinBlock:                   big.NewInt(0),
		LondonBlock:                   big.NewInt(0),
		AvocadoBlock:                  big.NewInt(0),
		PangyoBlock:                   big.NewInt(0),
		ApplepieBlock:                 big.NewInt(0),
		BokbunjaBlock:                 big.NewInt(0),
		CamelliaBlock:                 big.NewInt(0),
		ShanghaiTime:                  nil,
		CancunTime:                    nil,
		TerminalTotalDifficultyPassed: true,
		Ethash:                        new(params.EthashConfig),
	}
}

// TestValidateIntrinsicGasFollowsCamellia pins the pool's intrinsic-gas floor to
// the rules the EVM actually applies.
//
// EIP-3860 charges for each word of init code. Execution picks that up from
// ChainConfig.Rules(), which turns Camellia into Shanghai; the pool asked
// IsShanghai directly, which is false on a chain with no ShanghaiTime. A
// creation transaction carrying gas between the two floors was therefore
// admitted to the pool and propagated, and could never execute — the block
// builder drops it (issue #71).
func TestValidateIntrinsicGasFollowsCamellia(t *testing.T) {
	var (
		config = camelliaOnlyChainConfig()
		key, _ = crypto.GenerateKey()
		signer = types.LatestSigner(config)
		// 100 words of init code, so the EIP-3860 surcharge is visible.
		initcode = make([]byte, 32*100)
	)
	head := &types.Header{
		Number:   big.NewInt(1),
		GasLimit: 30_000_000,
		BaseFee:  big.NewInt(params.InitialBaseFee),
		Time:     1,
	}
	// Confirm the chain does run the Shanghai rules, or the rest proves nothing.
	if !config.Rules(head.Number, false, head.Time).IsShanghai {
		t.Fatal("Camellia chain does not report the Shanghai rules")
	}

	withInitcodeCost, err := core.IntrinsicGas(initcode, nil, true, true, true, true)
	if err != nil {
		t.Fatalf("intrinsic gas with the initcode cost: %v", err)
	}
	withoutInitcodeCost, err := core.IntrinsicGas(initcode, nil, true, true, true, false)
	if err != nil {
		t.Fatalf("intrinsic gas without the initcode cost: %v", err)
	}
	if withInitcodeCost <= withoutInitcodeCost {
		t.Fatalf("the two floors are equal (%d), so this test cannot detect the gate", withInitcodeCost)
	}

	validate := func(gas uint64) error {
		tx := types.MustSignNewTx(key, signer, &types.DynamicFeeTx{
			ChainID:   config.ChainID,
			Nonce:     0,
			GasTipCap: big.NewInt(1),
			GasFeeCap: big.NewInt(params.InitialBaseFee + 1),
			Gas:       gas,
			To:        nil, // contract creation
			Data:      initcode,
		})
		return ValidateTransaction(tx, head, signer, &ValidationOptions{
			Config:  config,
			Accept:  1<<types.LegacyTxType | 1<<types.AccessListTxType | 1<<types.DynamicFeeTxType,
			MaxSize: 2 * 1024 * 1024,
			MinTip:  new(big.Int),
		})
	}

	// Gas that covers the pre-EIP-3860 floor only: admitted before the fix,
	// unexecutable either way.
	if err := validate(withoutInitcodeCost); !errors.Is(err, core.ErrIntrinsicGas) {
		t.Errorf("gas %d (below the Shanghai floor %d) was not rejected: %v",
			withoutInitcodeCost, withInitcodeCost, err)
	}
	// One below the real floor must still be rejected.
	if err := validate(withInitcodeCost - 1); !errors.Is(err, core.ErrIntrinsicGas) {
		t.Errorf("gas %d (one below the floor) was not rejected: %v", withInitcodeCost-1, err)
	}
	// And the floor itself must pass.
	if err := validate(withInitcodeCost); err != nil {
		t.Errorf("gas %d (exactly the floor) was rejected: %v", withInitcodeCost, err)
	}
}

// TestValidateInitCodeSizeFollowsCamellia covers the other gate that asked
// IsShanghai alone. The EIP-3860 size limit is unreachable through the pool's
// own MaxSize on the production configuration (txMaxSize is the smaller of the
// two), so this checks the gate directly with a MaxSize that lets the init code
// through.
func TestValidateInitCodeSizeFollowsCamellia(t *testing.T) {
	var (
		config = camelliaOnlyChainConfig()
		key, _ = crypto.GenerateKey()
		signer = types.LatestSigner(config)
	)
	head := &types.Header{
		Number:   big.NewInt(1),
		GasLimit: 30_000_000,
		BaseFee:  big.NewInt(params.InitialBaseFee),
		Time:     1,
	}
	oversized := make([]byte, params.MaxInitCodeSize+1)
	tx := types.MustSignNewTx(key, signer, &types.DynamicFeeTx{
		ChainID:   config.ChainID,
		Nonce:     0,
		GasTipCap: big.NewInt(1),
		GasFeeCap: big.NewInt(params.InitialBaseFee + 1),
		Gas:       head.GasLimit,
		To:        nil,
		Data:      oversized,
	})
	err := ValidateTransaction(tx, head, signer, &ValidationOptions{
		Config:  config,
		Accept:  1<<types.LegacyTxType | 1<<types.AccessListTxType | 1<<types.DynamicFeeTxType,
		MaxSize: uint64(len(oversized)) + 64*1024, // do not let MaxSize decide
		MinTip:  new(big.Int),
	})
	if !errors.Is(err, core.ErrMaxInitCodeSizeExceeded) {
		t.Errorf("init code of %d bytes (limit %d) was not rejected: %v",
			len(oversized), params.MaxInitCodeSize, err)
	}
}
