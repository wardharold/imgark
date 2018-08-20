package cmd

import (
	"context"
	"log"
	"net/http"
	"os"
)

// Liveness responds to HTTP requests with a 200. It is the
// simplest possible K8S liveness probe handler.
func Liveness(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

// MustGetenv retrieves the value of an environment variable or logs a fatal error.
func MustGetenv(name string) string {
	val := os.Getenv(name)
	if len(val) == 0 {
		log.Fatalf("%s must be set", name)
	}
	return val
}

// Creates a handler for an HTTP prestop lifecycle hook.
func Prestop(cancel context.CancelFunc) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Cancelling ReceiveAndProcess")
		cancel()

		w.WriteHeader(http.StatusOK)
	}
}

// Readiness responds to HTTP requests with a 200. It is the
// simplest possible K8S readiness probe handler.
func Readiness(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}
