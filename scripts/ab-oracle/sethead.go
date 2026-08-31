// sethead: rewrite geth head-marker keys in a stopped leveldb chaindata copy
// so a pre-Camellia gmet (0.10.2) can open it as a read-only oracle.
//
//	usage: sethead <chaindata> <headerFastHashHex> <blockHashHex>
//
// LastBlock is pointed at a block whose state exists (genesis on a fresh full
// sync) so 0.10.2 skips the state-repair walk; LastHeader/LastFast are pointed
// at the last pre-fork block so its startup truncates the freezer at the fork
// boundary instead of nuking it to zero.
package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	"github.com/syndtr/goleveldb/leveldb"
)

func main() {
	if len(os.Args) != 4 {
		fmt.Fprintln(os.Stderr, "usage: sethead <chaindata> <headerFastHashHex> <blockHashHex>")
		os.Exit(1)
	}
	path := os.Args[1]
	nh, err1 := hex.DecodeString(strings.TrimPrefix(os.Args[2], "0x"))
	gh, err2 := hex.DecodeString(strings.TrimPrefix(os.Args[3], "0x"))
	if err1 != nil || err2 != nil || len(nh) != 32 || len(gh) != 32 {
		fmt.Fprintln(os.Stderr, "hashes must be 32-byte hex")
		os.Exit(1)
	}
	db, err := leveldb.OpenFile(path, nil)
	if err != nil {
		fmt.Fprintln(os.Stderr, "open:", err)
		os.Exit(1)
	}
	defer db.Close()

	show := func(when string) {
		for _, k := range []string{"LastBlock", "LastHeader", "LastFast"} {
			v, _ := db.Get([]byte(k), nil)
			fmt.Printf("%s %s=%x\n", when, k, v)
		}
	}
	show("before")
	must := func(k string, v []byte) {
		if err := db.Put([]byte(k), v, nil); err != nil {
			fmt.Fprintln(os.Stderr, "put", k, ":", err)
			os.Exit(1)
		}
	}
	must("LastBlock", gh)
	must("LastHeader", nh)
	must("LastFast", nh)
	show("after")
}
