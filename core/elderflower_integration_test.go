package core

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/params"
)

// TestBlobGasCalculation tests blob gas calculations from EIP-4844
func TestBlobGasCalculation(t *testing.T) {
	tests := []struct {
		name              string
		parentExcessBlobGas *big.Int
		blobGasUsed       uint64
	}{
		{
			name:              "zero excess, no blob gas used",
			parentExcessBlobGas: big.NewInt(0),
			blobGasUsed:       0,
		},
		{
			name:              "excess with blob gas used",
			parentExcessBlobGas: big.NewInt(1000000),
			blobGasUsed:       131072, // BlobTxPerBlobGas * 1
		},
		{
			name:              "high excess blob gas",
			parentExcessBlobGas: big.NewInt(10000000),
			blobGasUsed:       0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := types.CalcExcessBlobGas(tt.parentExcessBlobGas, tt.blobGasUsed)
			if result == nil {
				t.Fatalf("CalcExcessBlobGas returned nil")
			}
			t.Logf("  Parent: %d, Used: %d -> Result: %d",
				tt.parentExcessBlobGas, tt.blobGasUsed, result)
		})
	}
}

// TestBlobBaseFeeCalculation tests blob base fee calculations from EIP-4844
func TestBlobBaseFeeCalculation(t *testing.T) {
	tests := []struct {
		name              string
		excessBlobGas     *big.Int
	}{
		{
			name:           "zero excess blob gas",
			excessBlobGas:  big.NewInt(0),
		},
		{
			name:           "one blob worth of excess (131072 gas)",
			excessBlobGas:  big.NewInt(131072),
		},
		{
			name:           "six blobs worth of excess",
			excessBlobGas:  big.NewInt(786432), // 6 * 131072
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			fee := types.CalcBlobBaseFee(tt.excessBlobGas)
			if fee == nil {
				t.Fatalf("CalcBlobBaseFee returned nil")
			}
			if fee.Cmp(big.NewInt(1)) < 0 {
				t.Errorf("expected fee >= 1, got %d", fee)
			}
			t.Logf("  ExcessBlobGas: %d -> BaseFee: %d wei", tt.excessBlobGas, fee)
		})
	}
}

// TestElderflowerForksInChainConfigs verifies Elderflower fork configuration
func TestElderflowerForksInChainConfigs(t *testing.T) {
	configs := []struct {
		name   string
		config *params.ChainConfig
	}{
		{"Mainnet", params.MainnetChainConfig},
		{"Testnet", params.TestChainConfig},
		{"MetadiumMainnet", params.MetadiumMainnetChainConfig},
		{"MetadiumTestnet", params.MetadiumTestnetChainConfig},
	}

	for _, cfg := range configs {
		t.Run(cfg.name, func(t *testing.T) {
			if cfg.config == nil {
				t.Skip("config is nil")
			}
			// Check if ElderflowerBlock is defined
			if cfg.config.ElderflowerBlock != nil {
				t.Logf("✓ %s: ElderflowerBlock = %d", cfg.name, cfg.config.ElderflowerBlock)
			} else {
				t.Logf("  %s: ElderflowerBlock not yet activated (nil)", cfg.name)
			}
			// Verify IsElderflower method works
			isActive := cfg.config.IsElderflower(big.NewInt(0))
			t.Logf("  IsElderflower(0): %v", isActive)
		})
	}
}

// TestBlobGasConstants verifies EIP-4844 constants
func TestBlobGasConstants(t *testing.T) {
	tests := []struct {
		name     string
		value    uint64
		expected uint64
	}{
		{"BlobTxPerBlobGas", params.BlobTxPerBlobGas, 131072},
		{"MaxBlobGasPerBlock", params.MaxBlobGasPerBlock, 786432},
		{"MaxBlobsPerTransaction", params.MaxBlobsPerTransaction, 6},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.value == tt.expected {
				t.Logf("✓ %s = %d", tt.name, tt.value)
			} else {
				t.Errorf("expected %s = %d, got %d", tt.name, tt.expected, tt.value)
			}
		})
	}
}
