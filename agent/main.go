package main

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type TCPResult struct {
	Host      string  `json:"host"`
	Port      int     `json:"port"`
	Success   bool    `json:"success"`
	LatencyMs float64 `json:"latency_ms"`
	Error     string  `json:"error,omitempty"`
	Timestamp string  `json:"timestamp"`
}

type DNSResult struct {
	Host       string   `json:"host"`
	IPs        []string `json:"ips"`
	ResolvedIn float64  `json:"resolved_ms"`
	IsPrivate  []bool   `json:"is_private"`
	SplitBrain bool     `json:"split_brain"`
	AzureDNS   bool     `json:"azure_dns"`
	Error      string   `json:"error,omitempty"`
	Timestamp  string   `json:"timestamp"`
}

type CertInfo struct {
	Subject  string `json:"subject"`
	Issuer   string `json:"issuer"`
	NotAfter string `json:"not_after"`
	DaysLeft int    `json:"days_left"`
	Type     string `json:"type"`
}

type TLSResult struct {
	Host        string     `json:"host"`
	Port        int        `json:"port"`
	Success     bool       `json:"success"`
	TLSVersion  string     `json:"tls_version"`
	CipherSuite string     `json:"cipher_suite"`
	Trusted     bool       `json:"trusted"`
	TrustError  string     `json:"trust_error,omitempty"`
	Certificate *CertInfo  `json:"certificate,omitempty"`
	Chain       []CertInfo `json:"chain,omitempty"`
	LatencyMs   float64    `json:"latency_ms"`
	Error       string     `json:"error,omitempty"`
	Timestamp   string     `json:"timestamp"`
}

type PingResult struct {
	Host       string    `json:"host"`
	Sent       int       `json:"sent"`
	Received   int       `json:"received"`
	PacketLoss float64   `json:"packet_loss_pct"`
	MinMs      float64   `json:"min_ms"`
	AvgMs      float64   `json:"avg_ms"`
	MaxMs      float64   `json:"max_ms"`
	RTTs       []float64 `json:"rtts"`
	Error      string    `json:"error,omitempty"`
	Timestamp  string    `json:"timestamp"`
}

type AgentInfo struct {
	Version   string `json:"version"`
	Hostname  string `json:"hostname"`
	OS        string `json:"os"`
	Arch      string `json:"arch"`
	Uptime    string `json:"uptime"`
	Timestamp string `json:"timestamp"`
}

var startTime = time.Now()

func now() string { return time.Now().UTC().Format(time.RFC3339) }

func isPrivateIP(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	private := []string{"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "169.254.0.0/16"}
	for _, cidr := range private {
		_, network, _ := net.ParseCIDR(cidr)
		if network.Contains(parsed) {
			return true
		}
	}
	return false
}

func tlsVersionName(v uint16) string {
	switch v {
	case tls.VersionTLS10:
		return "TLS 1.0"
	case tls.VersionTLS11:
		return "TLS 1.1"
	case tls.VersionTLS12:
		return "TLS 1.2"
	case tls.VersionTLS13:
		return "TLS 1.3"
	default:
		return fmt.Sprintf("Unknown (0x%04x)", v)
	}
}

func cipherName(id uint16) string {
	switch id {
	case tls.TLS_AES_128_GCM_SHA256:
		return "TLS_AES_128_GCM_SHA256"
	case tls.TLS_AES_256_GCM_SHA384:
		return "TLS_AES_256_GCM_SHA384"
	case tls.TLS_CHACHA20_POLY1305_SHA256:
		return "TLS_CHACHA20_POLY1305_SHA256"
	case tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:
		return "ECDHE-RSA-AES128-GCM-SHA256"
	case tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:
		return "ECDHE-RSA-AES256-GCM-SHA384"
	case tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:
		return "ECDHE-ECDSA-AES128-GCM-SHA256"
	default:
		return fmt.Sprintf("0x%04x", id)
	}
}

func certType(cert *x509.Certificate) string {
	if cert.IsCA && cert.Issuer.String() == cert.Subject.String() {
		return "Root CA"
	}
	if cert.IsCA {
		return "Intermediate CA"
	}
	if cert.Issuer.String() == cert.Subject.String() {
		return "Self-Signed"
	}
	issuer := cert.Issuer.String()
	publicCAs := []string{"DigiCert", "Let's Encrypt", "Sectigo", "GlobalSign", "Comodo", "GeoTrust", "Entrust", "VeriSign"}
	for _, ca := range publicCAs {
		if strings.Contains(issuer, ca) {
			return "Publicly Trusted CA"
		}
	}
	return "Private / Internal CA"
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func parseRequest(r *http.Request) (host string, port int, err error) {
	host = r.URL.Query().Get("host")
	portStr := r.URL.Query().Get("port")
	if host == "" {
		var body struct {
			Host string `json:"host"`
			Port int    `json:"port"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		host = body.Host
		port = body.Port
	}
	if host == "" {
		return "", 0, fmt.Errorf("host is required")
	}
	if portStr != "" {
		port, err = strconv.Atoi(portStr)
		if err != nil {
			return "", 0, fmt.Errorf("invalid port")
		}
	}
	return host, port, nil
}

func handleInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	hostname, _ := os.Hostname()
	writeJSON(w, http.StatusOK, AgentInfo{
		Version:   "1.0.0",
		Hostname:  hostname,
		OS:        runtime.GOOS,
		Arch:      runtime.GOARCH,
		Uptime:    time.Since(startTime).Round(time.Second).String(),
		Timestamp: now(),
	})
}

func handleTCP(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, port, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, TCPResult{Error: err.Error(), Timestamp: now()})
		return
	}
	if port == 0 {
		port = 80
	}
	addr := fmt.Sprintf("%s:%d", host, port)
	start := time.Now()
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	latency := float64(time.Since(start).Microseconds()) / 1000.0
	result := TCPResult{Host: host, Port: port, LatencyMs: math.Round(latency*100) / 100, Timestamp: now()}
	if err != nil {
		result.Success = false
		result.Error = err.Error()
	} else {
		conn.Close()
		result.Success = true
	}
	writeJSON(w, http.StatusOK, result)
}

func handleDNS(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, _, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, DNSResult{Error: err.Error(), Timestamp: now()})
		return
	}
	start := time.Now()
	addrs, err := net.LookupHost(host)
	resolvedIn := float64(time.Since(start).Microseconds()) / 1000.0
	result := DNSResult{
		Host:       host,
		ResolvedIn: math.Round(resolvedIn*100) / 100,
		Timestamp:  now(),
		AzureDNS:   strings.Contains(host, ".azure.") || strings.Contains(host, ".windows.net") || strings.Contains(host, ".blob.") || strings.Contains(host, ".database.windows.net"),
	}
	if err != nil {
		result.Error = err.Error()
		writeJSON(w, http.StatusOK, result)
		return
	}
	result.IPs = addrs
	hasPrivate, hasPublic := false, false
	for _, ip := range addrs {
		priv := isPrivateIP(ip)
		result.IsPrivate = append(result.IsPrivate, priv)
		if priv {
			hasPrivate = true
		} else {
			hasPublic = true
		}
	}
	result.SplitBrain = hasPrivate && hasPublic
	writeJSON(w, http.StatusOK, result)
}

func handleTLS(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, port, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, TLSResult{Error: err.Error(), Timestamp: now()})
		return
	}
	if port == 0 {
		port = 443
	}
	addr := fmt.Sprintf("%s:%d", host, port)
	result := TLSResult{Host: host, Port: port, Timestamp: now()}
	start := time.Now()
	conn, err := tls.DialWithDialer(
		&net.Dialer{Timeout: 8 * time.Second},
		"tcp", addr,
		&tls.Config{InsecureSkipVerify: true, ServerName: host},
	)
	result.LatencyMs = math.Round(float64(time.Since(start).Microseconds())/10) / 100
	if err != nil {
		result.Success = false
		result.Error = err.Error()
		writeJSON(w, http.StatusOK, result)
		return
	}
	defer conn.Close()
	result.Success = true
	state := conn.ConnectionState()
	result.TLSVersion = tlsVersionName(state.Version)
	result.CipherSuite = cipherName(state.CipherSuite)
	if len(state.PeerCertificates) > 0 {
		leaf := state.PeerCertificates[0]
		daysLeft := int(time.Until(leaf.NotAfter).Hours() / 24)
		result.Certificate = &CertInfo{
			Subject:  leaf.Subject.String(),
			Issuer:   leaf.Issuer.String(),
			NotAfter: leaf.NotAfter.Format("2006-01-02"),
			DaysLeft: daysLeft,
			Type:     certType(leaf),
		}
		for _, cert := range state.PeerCertificates {
			dl := int(time.Until(cert.NotAfter).Hours() / 24)
			result.Chain = append(result.Chain, CertInfo{
				Subject:  cert.Subject.CommonName,
				Issuer:   cert.Issuer.CommonName,
				NotAfter: cert.NotAfter.Format("2006-01-02"),
				DaysLeft: dl,
				Type:     certType(cert),
			})
		}
	}
	_, trustErr := tls.DialWithDialer(
		&net.Dialer{Timeout: 8 * time.Second},
		"tcp", addr,
		&tls.Config{ServerName: host},
	)
	if trustErr != nil {
		result.Trusted = false
		result.TrustError = trustErr.Error()
	} else {
		result.Trusted = true
	}
	writeJSON(w, http.StatusOK, result)
}

func handlePing(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, _, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, PingResult{Error: err.Error(), Timestamp: now()})
		return
	}
	result := PingResult{Host: host, Sent: 4, Timestamp: now()}
	out, err := exec.Command("ping", "-c", "4", "-W", "3", host).Output()
	if err != nil {
		var rtts []float64
		received := 0
		for i := 0; i < 4; i++ {
			start := time.Now()
			conn, e := net.DialTimeout("tcp", host+":80", 3*time.Second)
			if e == nil {
				conn.Close()
				rtt := float64(time.Since(start).Microseconds()) / 1000.0
				rtts = append(rtts, math.Round(rtt*100)/100)
				received++
			}
		}
		result.Received = received
		result.RTTs = rtts
		result.PacketLoss = math.Round(float64(4-received)/4*100*100) / 100
		if len(rtts) > 0 {
			min, max, sum := rtts[0], rtts[0], 0.0
			for _, v := range rtts {
				if v < min {
					min = v
				}
				if v > max {
					max = v
				}
				sum += v
			}
			result.MinMs = min
			result.MaxMs = max
			result.AvgMs = math.Round(sum/float64(len(rtts))*100) / 100
		}
		writeJSON(w, http.StatusOK, result)
		return
	}
	lines := strings.Split(string(out), "\n")
	for _, line := range lines {
		if strings.Contains(line, "packets transmitted") {
			parts := strings.Fields(line)
			for i, p := range parts {
				if p == "transmitted," && i > 0 {
					result.Sent, _ = strconv.Atoi(parts[i-1])
				}
				if p == "received," && i > 0 {
					result.Received, _ = strconv.Atoi(parts[i-1])
				}
			}
			result.PacketLoss = math.Round(float64(result.Sent-result.Received)/float64(result.Sent)*100*100) / 100
		}
		if strings.Contains(line, "rtt min") {
			parts := strings.Split(line, "=")
			if len(parts) == 2 {
				stats := strings.Split(strings.TrimSpace(parts[1]), "/")
				if len(stats) >= 3 {
					result.MinMs, _ = strconv.ParseFloat(strings.TrimSpace(stats[0]), 64)
					result.AvgMs, _ = strconv.ParseFloat(strings.TrimSpace(stats[1]), 64)
					result.MaxMs, _ = strconv.ParseFloat(strings.TrimSpace(stats[2]), 64)
				}
			}
		}
	}
	writeJSON(w, http.StatusOK, result)
}

func main() {
	port := os.Getenv("AGENT_PORT")
	if port == "" {
		port = "8080"
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/info", handleInfo)
	mux.HandleFunc("/api/test/tcp", handleTCP)
	mux.HandleFunc("/api/test/dns", handleDNS)
	mux.HandleFunc("/api/test/tls", handleTLS)
	mux.HandleFunc("/api/test/ping", handlePing)
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	log.Printf("AzureSphere Agent v1.0.0 listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}
