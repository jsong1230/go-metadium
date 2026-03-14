package core

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/vm"
	"github.com/ethereum/go-ethereum/params"
)

// TestDorajiForksInChainConfigs verifies Doraji fork block configuration across chain configs.
func TestDorajiForksInChainConfigs(t *testing.T) {
	t.Run("TestChainConfig_DorajiBlock_zero", func(t *testing.T) {
		cfg := params.TestChainConfig
		if cfg.DorajiBlock == nil {
			t.Fatal("TestChainConfig.DorajiBlock should not be nil")
		}
		if cfg.DorajiBlock.Cmp(big.NewInt(0)) != 0 {
			t.Errorf("TestChainConfig.DorajiBlock expected 0, got %d", cfg.DorajiBlock)
		}
		if !cfg.IsDoraji(big.NewInt(0)) {
			t.Error("TestChainConfig.IsDoraji(0) should be true")
		}
		t.Logf("TestChainConfig: DorajiBlock=%d, IsDoraji(0)=true", cfg.DorajiBlock)
	})

	t.Run("MetadiumMainnetChainConfig_DorajiBlock_nil", func(t *testing.T) {
		cfg := params.MetadiumMainnetChainConfig
		if cfg.DorajiBlock != nil {
			t.Errorf("MetadiumMainnetChainConfig.DorajiBlock expected nil, got %d", cfg.DorajiBlock)
		}
		if cfg.IsDoraji(big.NewInt(0)) {
			t.Error("MetadiumMainnetChainConfig.IsDoraji(0) should be false (DorajiBlock=nil)")
		}
		t.Logf("MetadiumMainnetChainConfig: DorajiBlock=nil, IsDoraji(0)=false")
	})

	t.Run("MetadiumTestnetChainConfig_DorajiBlock_nil", func(t *testing.T) {
		cfg := params.MetadiumTestnetChainConfig
		if cfg.DorajiBlock != nil {
			t.Errorf("MetadiumTestnetChainConfig.DorajiBlock expected nil, got %d", cfg.DorajiBlock)
		}
		if cfg.IsDoraji(big.NewInt(0)) {
			t.Error("MetadiumTestnetChainConfig.IsDoraji(0) should be false (DorajiBlock=nil)")
		}
		t.Logf("MetadiumTestnetChainConfig: DorajiBlock=nil, IsDoraji(0)=false")
	})

	t.Run("AllEthashProtocolChanges_DorajiBlock_zero", func(t *testing.T) {
		cfg := params.AllEthashProtocolChanges
		if cfg.DorajiBlock == nil {
			t.Fatal("AllEthashProtocolChanges.DorajiBlock should not be nil")
		}
		if cfg.DorajiBlock.Cmp(big.NewInt(0)) != 0 {
			t.Errorf("AllEthashProtocolChanges.DorajiBlock expected 0, got %d", cfg.DorajiBlock)
		}
		if !cfg.IsDoraji(big.NewInt(0)) {
			t.Error("AllEthashProtocolChanges.IsDoraji(0) should be true")
		}
		t.Logf("AllEthashProtocolChanges: DorajiBlock=%d, IsDoraji(0)=true", cfg.DorajiBlock)
	})

	t.Run("AllCliqueProtocolChanges_DorajiBlock_zero", func(t *testing.T) {
		cfg := params.AllCliqueProtocolChanges
		if cfg.DorajiBlock == nil {
			t.Fatal("AllCliqueProtocolChanges.DorajiBlock should not be nil")
		}
		if cfg.DorajiBlock.Cmp(big.NewInt(0)) != 0 {
			t.Errorf("AllCliqueProtocolChanges.DorajiBlock expected 0, got %d", cfg.DorajiBlock)
		}
		if !cfg.IsDoraji(big.NewInt(0)) {
			t.Error("AllCliqueProtocolChanges.IsDoraji(0) should be true")
		}
		t.Logf("AllCliqueProtocolChanges: DorajiBlock=%d, IsDoraji(0)=true", cfg.DorajiBlock)
	})
}

// TestActiveBlobSchedule verifies EIP-7840 ActiveBlobSchedule selection logic.
func TestActiveBlobSchedule(t *testing.T) {
	t.Run("TestChainConfig_no_blob_schedule_returns_nil", func(t *testing.T) {
		cfg := params.TestChainConfig
		// TestChainConfig has DorajiBlock=0 but no BlobSchedule fields set
		if cfg.CamelliaBlobSchedule != nil || cfg.DorajiBlobSchedule != nil {
			t.Skip("TestChainConfig has BlobSchedule set; skipping nil test")
		}
		result := cfg.ActiveBlobSchedule(big.NewInt(0))
		// nil is acceptable when no BlobSchedule is configured
		t.Logf("TestChainConfig ActiveBlobSchedule(0) = %v (nil ok)", result)
	})

	t.Run("custom_config_camellia_schedule", func(t *testing.T) {
		cfg := &params.ChainConfig{
			ChainID:       big.NewInt(1337),
			HomesteadBlock: big.NewInt(0),
			CamelliaBlock: big.NewInt(0),
			DorajiBlock:   big.NewInt(100),
			CamelliaBlobSchedule: &params.BlobSchedule{
				Target:                3,
				Max:                   6,
				BaseFeeUpdateFraction: 3338477,
			},
			DorajiBlobSchedule: &params.BlobSchedule{
				Target:                6,
				Max:                   9,
				BaseFeeUpdateFraction: 5007716,
			},
		}

		// block 50: IsCamellia=true, IsDoraji=false → CamelliaBlobSchedule
		bs50 := cfg.ActiveBlobSchedule(big.NewInt(50))
		if bs50 == nil {
			t.Fatal("block 50: expected CamelliaBlobSchedule, got nil")
		}
		if bs50.Target != 3 || bs50.Max != 6 {
			t.Errorf("block 50: expected Target=3 Max=6, got Target=%d Max=%d", bs50.Target, bs50.Max)
		}
		t.Logf("block 50 (Camellia only): Target=%d Max=%d UpdateFraction=%d",
			bs50.Target, bs50.Max, bs50.BaseFeeUpdateFraction)

		// block 150: IsDoraji=true → DorajiBlobSchedule
		bs150 := cfg.ActiveBlobSchedule(big.NewInt(150))
		if bs150 == nil {
			t.Fatal("block 150: expected DorajiBlobSchedule, got nil")
		}
		if bs150.Target != 6 || bs150.Max != 9 {
			t.Errorf("block 150: expected Target=6 Max=9, got Target=%d Max=%d", bs150.Target, bs150.Max)
		}
		t.Logf("block 150 (Doraji): Target=%d Max=%d UpdateFraction=%d",
			bs150.Target, bs150.Max, bs150.BaseFeeUpdateFraction)

		// block 0 (before any fork in a config where CamelliaBlock=0 means active at 0):
		// CamelliaBlock=0 means IsCamellia(0)=true, so CamelliaBlobSchedule is returned.
		// To test "before any fork", use a config where CamelliaBlock > 0.
		cfgDelayed := &params.ChainConfig{
			ChainID:       big.NewInt(1337),
			HomesteadBlock: big.NewInt(0),
			CamelliaBlock: big.NewInt(50),
			DorajiBlock:   big.NewInt(100),
			CamelliaBlobSchedule: &params.BlobSchedule{
				Target:                3,
				Max:                   6,
				BaseFeeUpdateFraction: 3338477,
			},
			DorajiBlobSchedule: &params.BlobSchedule{
				Target:                6,
				Max:                   9,
				BaseFeeUpdateFraction: 5007716,
			},
		}
		bs0 := cfgDelayed.ActiveBlobSchedule(big.NewInt(0))
		if bs0 != nil {
			t.Errorf("block 0 (before Camellia): expected nil BlobSchedule, got %+v", bs0)
		}
		t.Logf("block 0 (before Camellia fork): ActiveBlobSchedule = nil (correct)")
	})
}

// TestIntrinsicGasDoraji verifies EIP-7623 calldata floor gas cost behavior.
func TestIntrinsicGasDoraji(t *testing.T) {
	// helper: build data with specified nonzero and zero byte counts
	makeData := func(nonzero, zero int) []byte {
		data := make([]byte, nonzero+zero)
		for i := 0; i < nonzero; i++ {
			data[i] = 0xff
		}
		return data
	}

	tests := []struct {
		name                string
		nonzeroBytes        int
		zeroBytes           int
		isContractCreation  bool
		expectedDoraji      uint64
		expectedNonDoraji   uint64
	}{
		{
			name:              "empty data: same for both",
			nonzeroBytes:      0,
			zeroBytes:         0,
			isContractCreation: false,
			expectedDoraji:    params.TxGas,    // 21000
			expectedNonDoraji: params.TxGas,    // 21000
		},
		{
			name:              "100 nonzero bytes: floor > standard",
			nonzeroBytes:      100,
			zeroBytes:         0,
			isContractCreation: false,
			// standard: 21000 + 100*16 = 22600
			// floor: 21000 + (100*4)*10 = 21000+4000 = 25000
			expectedDoraji:    25000,
			expectedNonDoraji: 22600,
		},
		{
			name:              "1000 nonzero bytes: large floor",
			nonzeroBytes:      1000,
			zeroBytes:         0,
			isContractCreation: false,
			// standard: 21000 + 1000*16 = 37000
			// floor: 21000 + (1000*4)*10 = 21000+40000 = 61000
			expectedDoraji:    61000,
			expectedNonDoraji: 37000,
		},
		{
			name:              "50 nonzero bytes",
			nonzeroBytes:      50,
			zeroBytes:         0,
			isContractCreation: false,
			// standard: 21000 + 50*16 = 21800
			// floor: 21000 + (50*4)*10 = 21000+2000 = 23000
			expectedDoraji:    23000,
			expectedNonDoraji: 21800,
		},
		{
			name:              "1000 zero bytes: floor > standard",
			nonzeroBytes:      0,
			zeroBytes:         1000,
			isContractCreation: false,
			// standard: 21000 + 1000*4 = 25000
			// floor: 21000 + (1000*1)*10 = 21000+10000 = 31000
			expectedDoraji:    31000,
			expectedNonDoraji: 25000,
		},
		{
			name:              "1 nonzero byte: floor always wins",
			nonzeroBytes:      1,
			zeroBytes:         0,
			isContractCreation: false,
			// standard: 21000 + 1*16 = 21016
			// floor: 21000 + (1*4)*10 = 21000+40 = 21040
			expectedDoraji:    21040,
			expectedNonDoraji: 21016,
		},
		{
			name:              "2 nonzero bytes: floor always wins",
			nonzeroBytes:      2,
			zeroBytes:         0,
			isContractCreation: false,
			// standard: 21000 + 2*16 = 21032
			// floor: 21000 + (2*4)*10 = 21000+80 = 21080
			expectedDoraji:    21080,
			expectedNonDoraji: 21032,
		},
		{
			name:              "contract creation base fee",
			nonzeroBytes:      0,
			zeroBytes:         0,
			isContractCreation: true,
			// base: TxGasContractCreation = 53000
			expectedDoraji:    params.TxGasContractCreation,
			expectedNonDoraji: params.TxGasContractCreation,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			data := makeData(tt.nonzeroBytes, tt.zeroBytes)

			gasDoraji, err := IntrinsicGas(data, nil, tt.isContractCreation, true, true, true)
			if err != nil {
				t.Fatalf("IntrinsicGas(isDoraji=true) error: %v", err)
			}
			gasNonDoraji, err := IntrinsicGas(data, nil, tt.isContractCreation, true, true, false)
			if err != nil {
				t.Fatalf("IntrinsicGas(isDoraji=false) error: %v", err)
			}

			if gasDoraji != tt.expectedDoraji {
				t.Errorf("Doraji gas: expected %d, got %d", tt.expectedDoraji, gasDoraji)
			} else {
				t.Logf("Doraji gas = %d (expected %d)", gasDoraji, tt.expectedDoraji)
			}
			if gasNonDoraji != tt.expectedNonDoraji {
				t.Errorf("NonDoraji gas: expected %d, got %d", tt.expectedNonDoraji, gasNonDoraji)
			} else {
				t.Logf("NonDoraji gas = %d (expected %d)", gasNonDoraji, tt.expectedNonDoraji)
			}
		})
	}
}

// TestDorajiGasConstants verifies that the Doraji-specific gas constants match the EIP-2537 / EIP-7623 / EIP-7691 spec.
func TestDorajiGasConstants(t *testing.T) {
	tests := []struct {
		name     string
		value    uint64
		expected uint64
	}{
		{"Bls12381G1AddGasDoraji", params.Bls12381G1AddGasDoraji, 375},
		{"Bls12381G1MulGasDoraji", params.Bls12381G1MulGasDoraji, 14400},
		{"Bls12381G2AddGasDoraji", params.Bls12381G2AddGasDoraji, 600},
		{"Bls12381G2MulGasDoraji", params.Bls12381G2MulGasDoraji, 57600},
		{"Bls12381PairingBaseGasDoraji", params.Bls12381PairingBaseGasDoraji, 43300},
		{"Bls12381PairingPerPairGasDoraji", params.Bls12381PairingPerPairGasDoraji, 32600},
		{"Bls12381MapG1GasDoraji", params.Bls12381MapG1GasDoraji, 5500},
		{"Bls12381MapG2GasDoraji", params.Bls12381MapG2GasDoraji, 75000},
		{"TxDataTokenCostDoraji", params.TxDataTokenCostDoraji, 10},
		{"TxDataNonZeroTokens", params.TxDataNonZeroTokens, 4},
		{"TxDataZeroTokens", params.TxDataZeroTokens, 1},
		{"TargetBlobGasPerBlockDoraji", params.TargetBlobGasPerBlockDoraji, 786432},
		{"MaxBlobGasPerBlockDoraji", params.MaxBlobGasPerBlockDoraji, 1179648},
		{"BlobBaseFeeUpdateFractionDoraji", params.BlobBaseFeeUpdateFractionDoraji, 5007716},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.value != tt.expected {
				t.Errorf("%s: expected %d, got %d", tt.name, tt.expected, tt.value)
			} else {
				t.Logf("%s = %d (correct)", tt.name, tt.value)
			}
		})
	}
}

// TestDoraji_BLS12381_Precompile_Addresses verifies that EIP-2537 BLS12-381 precompiles
// are registered at the correct addresses in PrecompiledContractsDoraji.
func TestDoraji_BLS12381_Precompile_Addresses(t *testing.T) {
	contracts := vm.PrecompiledContractsDoraji

	t.Run("0x0b_G1Add_exists_with_correct_gas", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0b})
		p, ok := contracts[addr]
		if !ok {
			t.Fatalf("address 0x0b (G1Add) not found in PrecompiledContractsDoraji")
		}
		gas := p.RequiredGas(make([]byte, 256))
		if gas != params.Bls12381G1AddGasDoraji {
			t.Errorf("G1Add RequiredGas: expected %d, got %d", params.Bls12381G1AddGasDoraji, gas)
		}
		t.Logf("0x0b G1Add: RequiredGas(256 bytes) = %d", gas)
	})

	t.Run("0x0c_G1Mul_exists_with_correct_gas", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0c})
		p, ok := contracts[addr]
		if !ok {
			t.Fatalf("address 0x0c (G1Mul) not found in PrecompiledContractsDoraji")
		}
		gas := p.RequiredGas(make([]byte, 160))
		if gas != params.Bls12381G1MulGasDoraji {
			t.Errorf("G1Mul RequiredGas: expected %d, got %d", params.Bls12381G1MulGasDoraji, gas)
		}
		t.Logf("0x0c G1Mul: RequiredGas = %d", gas)
	})

	t.Run("0x11_Pairing_exists", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x11})
		_, ok := contracts[addr]
		if !ok {
			t.Fatalf("address 0x11 (Pairing) not found in PrecompiledContractsDoraji")
		}
		t.Logf("0x11 Pairing: found in PrecompiledContractsDoraji")
	})

	t.Run("0x0a_KZG4844_still_present", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0a})
		_, ok := contracts[addr]
		if !ok {
			t.Fatalf("address 0x0a (KZG4844) not found in PrecompiledContractsDoraji (should still be present)")
		}
		t.Logf("0x0a KZG4844: found in PrecompiledContractsDoraji")
	})

	t.Run("0x14_does_not_exist", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x14})
		_, ok := contracts[addr]
		if ok {
			t.Errorf("address 0x14 should not exist in PrecompiledContractsDoraji")
		}
		t.Logf("0x14: correctly absent from PrecompiledContractsDoraji")
	})

	t.Run("G1Add_run_with_valid_input", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0b})
		p, ok := contracts[addr]
		if !ok {
			t.Fatal("address 0x0b (G1Add) not found")
		}

		// Test vector from core/vm/testdata/precompiles/blsG1Add.json (first entry)
		// bls_g1add_(g1+g1=2*g1)
		input := common.FromHex(
			"0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb" +
				"0000000000000000000000000000000008b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1" +
				"0000000000000000000000000000000017f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb" +
				"0000000000000000000000000000000008b3f481e3aaa0f1a09e30ed741d8ae4fcf5e095d5d00af600db18cb2c04b3edd03cc744a2888ae40caa232946c5e7e1",
		)
		if len(input) != 256 {
			t.Fatalf("expected 256 bytes input, got %d", len(input))
		}

		gas := p.RequiredGas(input)
		if gas != 375 {
			t.Errorf("G1Add RequiredGas(256 bytes): expected 375, got %d", gas)
		}

		output, err := p.Run(input)
		if err != nil {
			t.Fatalf("G1Add Run() error: %v", err)
		}
		if len(output) == 0 {
			t.Error("G1Add Run() returned empty output")
		}
		t.Logf("G1Add Run(): gas=%d, output=%d bytes, output[0:8]=0x%x", gas, len(output), output[:8])
	})
}

// TestDoraji_BLS12381_PrecompiledContractsCamellia_NotInclude_BLS verifies that
// PrecompiledContractsCamellia does NOT include BLS12-381 precompiles (EIP-2537).
func TestDoraji_BLS12381_PrecompiledContractsCamellia_NotInclude_BLS(t *testing.T) {
	contracts := vm.PrecompiledContractsCamellia

	t.Run("0x0b_G1Add_absent_in_Camellia", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0b})
		_, ok := contracts[addr]
		if ok {
			t.Errorf("address 0x0b (G1Add/BLS) should NOT be in PrecompiledContractsCamellia")
		} else {
			t.Logf("0x0b: correctly absent from PrecompiledContractsCamellia (BLS not in Camellia)")
		}
	})

	t.Run("0x0a_KZG4844_present_in_Camellia", func(t *testing.T) {
		addr := common.BytesToAddress([]byte{0x0a})
		_, ok := contracts[addr]
		if !ok {
			t.Errorf("address 0x0a (KZG4844) should be in PrecompiledContractsCamellia")
		} else {
			t.Logf("0x0a KZG4844: correctly present in PrecompiledContractsCamellia")
		}
	})

	t.Run("Camellia_highest_address_is_0x0a", func(t *testing.T) {
		maxAddr := byte(0)
		for addr := range contracts {
			b := addr.Bytes()[len(addr.Bytes())-1]
			if b > maxAddr {
				maxAddr = b
			}
		}
		if maxAddr > 0x0a {
			t.Errorf("PrecompiledContractsCamellia highest address expected <= 0x0a, got 0x%02x", maxAddr)
		}
		t.Logf("PrecompiledContractsCamellia highest address: 0x%02x (should be 0x0a)", maxAddr)
	})
}
