package main

import (
	"fmt"
	"log"
	"os"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("Usage: go run cmd/hash-password/main.go <password>")
	}

	password := os.Args[1]

	// Generate hash with cost 12 (same as in migration)
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 12)
	if err != nil {
		log.Fatalf("Failed to generate hash: %v", err)
	}

	fmt.Printf("Password: %s\n", password)
	fmt.Printf("Hash: %s\n", string(hash))

	// Verify the hash works
	err = bcrypt.CompareHashAndPassword(hash, []byte(password))
	if err != nil {
		fmt.Printf("❌ Hash verification failed: %v\n", err)
	} else {
		fmt.Printf("✅ Hash verification successful!\n")
	}
}
