package main

import (
	"bufio"
	"crypto/tls"
	"crypto/sha1"
	"encoding/base64"
	"encoding/hex"
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

// ─── Response types ───────────────────────────────────────────────────────────

type TCPResult struct {
	Host      string  `json:"host"`
	Port      int     `json:"port"`
	Success   bool    `json:"success"`
	LatencyMs float64 `json:"latency_ms"`
	Error     string  `json:"error,omitempty"`
	Timestamp string  `json:"timestamp"`
}

type DNSResult struct {
	Host        string   `json:"host"`
	IPs         []string `json:"ips"`
	ResolvedIn  float64  `json:"resolved_ms"`
	IsPrivate   []bool   `json:"is_private"`
	SplitBrain  bool     `json:"split_brain"`
	AzureDNS    bool     `json:"azure_dns"`
	Error       string   `json:"error,omitempty"`
	Timestamp   string   `json:"timestamp"`
}

type CertInfo struct {
	Subject   string `json:"subject"`
	Issuer    string `json:"issuer"`
	NotAfter  string `json:"not_after"`
	NotBefore string `json:"not_before"`
	DaysLeft  int    `json:"days_left"`
	Type      string `json:"type"`
	Thumbprint string `json:"thumbprint"`
	Serial    string `json:"serial"`
	RawPEM    string `json:"raw_pem"`
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
	SANs        []string   `json:"sans,omitempty"`
	ChainErrors []string   `json:"chain_errors,omitempty"`
	LatencyMs   float64    `json:"latency_ms"`
	Error       string     `json:"error,omitempty"`
	Timestamp   string     `json:"timestamp"`
}

type HTTPRedirect struct {
	URL        string `json:"url"`
	StatusCode int    `json:"status_code"`
	StatusText string `json:"status_text"`
}

type HTTPResult struct {
	Host          string            `json:"host"`
	Port          int               `json:"port"`
	URL           string            `json:"url"`
	StatusCode    int               `json:"status_code"`
	StatusText    string            `json:"status_text"`
	Protocol      string            `json:"protocol"`
	Headers       map[string]string `json:"headers"`
	RedirectChain []HTTPRedirect    `json:"redirect_chain,omitempty"`
	FinalURL      string            `json:"final_url"`
	LatencyMs     float64           `json:"latency_ms"`
	BodySizeBytes int               `json:"body_size_bytes"`
	Success       bool              `json:"success"`
	Error         string            `json:"error,omitempty"`
	Timestamp     string            `json:"timestamp"`
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

func now() string { return time.Now().UTC().Format(time.RFC3339) }

func isPrivateIP(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	private := []string{
		"10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
		"169.254.0.0/16", "127.0.0.0/8", "::1/128", "fc00::/7",
	}
	for _, cidr := range private {
		_, network, _ := net.ParseCIDR(cidr)
		if network != nil && network.Contains(parsed) {
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
	// check if self-signed
	if cert.Issuer.String() == cert.Subject.String() {
		return "Self-Signed"
	}
	// check for known public CAs
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
		// try JSON body
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

// ─── Handlers ─────────────────────────────────────────────────────────────────

// GET /api/info
func handleInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	hostname, _ := os.Hostname()
	uptime := time.Since(startTime).Round(time.Second).String()
	writeJSON(w, http.StatusOK, AgentInfo{
		Version:   "1.0.0",
		Hostname:  hostname,
		OS:        runtime.GOOS,
		Arch:      runtime.GOARCH,
		Uptime:    uptime,
		Timestamp: now(),
	})
}

// POST /api/test/tcp   ?host=x&port=y
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

	result := TCPResult{
		Host:      host,
		Port:      port,
		LatencyMs: math.Round(latency*100) / 100,
		Timestamp: now(),
	}
	if err != nil {
		result.Success = false
		result.Error = err.Error()
	} else {
		conn.Close()
		result.Success = true
	}
	writeJSON(w, http.StatusOK, result)
}

// POST /api/test/dns   ?host=x
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
		AzureDNS:   strings.Contains(host, ".azure.") || strings.Contains(host, ".windows.net") || strings.Contains(host, ".blob.") || strings.Contains(host, ".servicebus.") || strings.Contains(host, ".database.windows.net"),
	}

	if err != nil {
		result.Error = err.Error()
		writeJSON(w, http.StatusOK, result)
		return
	}

	result.IPs = addrs
	hasPrivate := false
	hasPublic := false
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


// certToPEM converts raw DER bytes to PEM format string
func certToPEM(der []byte) string {
	b64 := base64.StdEncoding.EncodeToString(der)
	var lines []string
	for i := 0; i < len(b64); i += 64 {
		end := i + 64
		if end > len(b64) {
			end = len(b64)
		}
		lines = append(lines, b64[i:end])
	}
	pem := "-----BEGIN CERTIFICATE-----\n"
	for _, l := range lines {
		pem += l + "\n"
	}
	pem += "-----END CERTIFICATE-----\n"
	return pem
}

// POST /api/test/tls   ?host=x&port=y
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

	// ServerName must be a hostname, not a bare IP — Go TLS rejects IP SNI
	sniHost := host
	if net.ParseIP(host) != nil {
		sniHost = "" // empty SNI for IP targets; cert inspection still works
	}
	isIPTarget := net.ParseIP(host) != nil

	// Stage 1: TLS handshake with bypass (inspect cert regardless of trust)
	start := time.Now()
	conn, err := tls.DialWithDialer(
		&net.Dialer{Timeout: 8 * time.Second},
		"tcp", addr,
		&tls.Config{InsecureSkipVerify: true, ServerName: sniHost},
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

	// Certificate details
	if len(state.PeerCertificates) > 0 {
		leaf := state.PeerCertificates[0]
		daysLeft := int(time.Until(leaf.NotAfter).Hours() / 24)

		// Extract SANs
		var sans []string
		for _, dns := range leaf.DNSNames {
			sans = append(sans, dns)
		}
		for _, ip := range leaf.IPAddresses {
			sans = append(sans, ip.String())
		}

		// Build chain with validation
		x509chain := x509.NewCertPool()
		for _, c := range state.PeerCertificates[1:] {
			x509chain.AddCert(c)
		}
		var chainErrors []string
		opts := x509.VerifyOptions{Intermediates: x509chain}
		if _, err := leaf.Verify(opts); err != nil {
			chainErrors = append(chainErrors, err.Error())
		}

		result.SANs = sans
		result.ChainErrors = chainErrors
		thumb := sha1.Sum(leaf.Raw)
		result.Certificate = &CertInfo{
			Subject:    leaf.Subject.String(),
			Issuer:     leaf.Issuer.String(),
			NotAfter:   leaf.NotAfter.Format("2006-01-02"),
			NotBefore:  leaf.NotBefore.Format("2006-01-02"),
			DaysLeft:   daysLeft,
			Type:       certType(leaf),
			Thumbprint: hex.EncodeToString(thumb[:]),
			Serial:     leaf.SerialNumber.Text(16),
			RawPEM:     certToPEM(leaf.Raw),
		}
		for _, cert := range state.PeerCertificates {
			dl := int(time.Until(cert.NotAfter).Hours() / 24)
			t := sha1.Sum(cert.Raw)
			result.Chain = append(result.Chain, CertInfo{
				Subject:    cert.Subject.CommonName,
				Issuer:     cert.Issuer.CommonName,
				NotAfter:   cert.NotAfter.Format("2006-01-02"),
				NotBefore:  cert.NotBefore.Format("2006-01-02"),
				DaysLeft:   dl,
				Type:       certType(cert),
				Thumbprint: hex.EncodeToString(t[:]),
				Serial:     cert.SerialNumber.Text(16),
				RawPEM:     certToPEM(cert.Raw),
			})
		}
	}

	// Stage 2: Real-world trust validation (using system cert store)
	// Skip for bare IP targets — system store will never trust an IP-only self-signed cert
	if isIPTarget {
		result.Trusted = false
		result.TrustError = "IP target: certificate trust validation skipped (use FQDN for full trust check)"
	} else {
		_, trustErr := tls.DialWithDialer(
			&net.Dialer{Timeout: 4 * time.Second},
			"tcp", addr,
			&tls.Config{ServerName: sniHost},
		)
		if trustErr != nil {
			result.Trusted = false
			result.TrustError = trustErr.Error()
		} else {
			result.Trusted = true
		}
	}

	writeJSON(w, http.StatusOK, result)
}

// GET/POST /api/test/http   ?host=x&port=y&scheme=https
func handleHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, port, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, HTTPResult{Error: err.Error(), Timestamp: now()})
		return
	}
	scheme := r.URL.Query().Get("scheme")
	if scheme == "" {
		if port == 80 {
			scheme = "http"
		} else {
			scheme = "https"
		}
	}
	if port == 0 {
		if scheme == "http" {
			port = 80
		} else {
			port = 443
		}
	}

	targetURL := fmt.Sprintf("%s://%s:%d", scheme, host, port)
	result := HTTPResult{
		Host:      host,
		Port:      port,
		URL:       targetURL,
		Timestamp: now(),
	}

	var redirectChain []HTTPRedirect

	// Custom transport — skip TLS verify, track redirects manually
	transport := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		DialContext: (&net.Dialer{Timeout: 8 * time.Second}).DialContext,
	}
	client := &http.Client{
		Timeout:   10 * time.Second,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 10 {
				return fmt.Errorf("stopped after 10 redirects")
			}
			// Record the redirect we just followed
			prev := via[len(via)-1]
			redirectChain = append(redirectChain, HTTPRedirect{
				URL:        prev.URL.String(),
				StatusCode: 0, // filled below from response
				StatusText: "",
			})
			return nil
		},
	}

	start := time.Now()
	resp, err := client.Get(targetURL)
	result.LatencyMs = math.Round(float64(time.Since(start).Microseconds())/10) / 100

	if err != nil {
		result.Success = false
		result.Error = err.Error()
		writeJSON(w, http.StatusOK, result)
		return
	}
	defer resp.Body.Close()

	// Read up to 4KB of body just for size measurement
	body := make([]byte, 4096)
	n, _ := resp.Body.Read(body)

	result.Success = true
	result.StatusCode = resp.StatusCode
	result.StatusText = resp.Status
	result.FinalURL = resp.Request.URL.String()
	result.BodySizeBytes = n
	result.Protocol = resp.Proto

	// Capture key response headers
	important := []string{
		"Content-Type", "Content-Length", "Server", "X-Powered-By",
		"Strict-Transport-Security", "X-Content-Type-Options",
		"X-Frame-Options", "X-XSS-Protection", "Cache-Control",
		"Location", "Access-Control-Allow-Origin", "Set-Cookie",
		"WWW-Authenticate", "X-Request-Id", "X-Correlation-Id",
	}
	headers := make(map[string]string)
	for _, key := range important {
		if val := resp.Header.Get(key); val != "" {
			headers[key] = val
		}
	}
	// Also capture any SAP/Azure/custom x- headers
	for key, vals := range resp.Header {
		lk := strings.ToLower(key)
		if strings.HasPrefix(lk, "x-sap-") || strings.HasPrefix(lk, "x-ms-") || strings.HasPrefix(lk, "x-azure-") {
			headers[key] = strings.Join(vals, ", ")
		}
	}
	result.Headers = headers
	result.RedirectChain = redirectChain

	writeJSON(w, http.StatusOK, result)
}

// ─── Traceroute types ─────────────────────────────────────────────────────────

type TracerouteHop struct {
	Hop      int      `json:"hop"`
	IP       string   `json:"ip"`
	Hostname string   `json:"hostname,omitempty"`
	RTTs     []float64 `json:"rtts"`
	AvgRTT   float64  `json:"avg_rtt"`
	Timeout  bool     `json:"timeout"`
	ASN      string   `json:"asn,omitempty"`
	ISP      string   `json:"isp,omitempty"`
	Country  string   `json:"country,omitempty"`
	City     string   `json:"city,omitempty"`
	IsAzure  bool     `json:"is_azure"`
	IsPrivate bool    `json:"is_private"`
}

type TracerouteResult struct {
	Host      string          `json:"host"`
	Hops      []TracerouteHop `json:"hops"`
	Reached   bool            `json:"reached"`
	TotalHops int             `json:"total_hops"`
	Error     string          `json:"error,omitempty"`
	Timestamp string          `json:"timestamp"`
}

// GET /api/test/traceroute?host=x  — Server-Sent Events, streams hops in real time
func handleTraceroute(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host, _, err := parseRequest(r)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "streaming not supported", http.StatusInternalServerError)
		return
	}

	sendEvent := func(eventType string, data interface{}) {
		b, _ := json.Marshal(data)
		fmt.Fprintf(w, "event: %s\ndata: %s\n\n", eventType, string(b))
		flusher.Flush()
	}

	parseHop := func(line string) *TracerouteHop {
		line = strings.TrimSpace(line)
		if line == "" {
			return nil
		}
		fields := strings.Fields(line)
		if len(fields) < 2 {
			return nil
		}
		hopNum := 0
		fmt.Sscanf(fields[0], "%d", &hopNum)
		if hopNum == 0 {
			return nil
		}
		hop := &TracerouteHop{Hop: hopNum, Timeout: true}

		// Timeout check
		timeouts := 0
		for _, f := range fields[1:] {
			if f == "*" {
				timeouts++
			}
		}
		if timeouts == len(fields)-1 {
			return hop
		}

		// Extract IP
		for _, f := range fields[1:] {
			if net.ParseIP(f) != nil {
				hop.IP = f
				break
			}
		}
		if hop.IP == "" {
			return nil
		}
		hop.Timeout = false

		// Extract RTTs
		for _, f := range fields {
			f = strings.TrimSuffix(f, "ms")
			var v float64
			if _, e := fmt.Sscanf(f, "%f", &v); e == nil && v > 0 && v < 30000 {
				hop.RTTs = append(hop.RTTs, math.Round(v*100)/100)
			}
		}
		if len(hop.RTTs) > 0 {
			sum := 0.0
			for _, v := range hop.RTTs {
				sum += v
			}
			hop.AvgRTT = math.Round(sum/float64(len(hop.RTTs))*100) / 100
		}

		hop.IsPrivate = isPrivateIP(hop.IP)
		hop.IsAzure = isAzureIP(hop.IP)

		if !hop.IsPrivate {
			if geo := lookupGeo(hop.IP); geo != nil {
				hop.ASN = geo.ASN
				hop.ISP = geo.ISP
				hop.Country = geo.Country
				hop.City = geo.City
			}
		}
		if names, e := net.LookupAddr(hop.IP); e == nil && len(names) > 0 {
			hop.Hostname = strings.TrimSuffix(names[0], ".")
		}
		return hop
	}

	// Start traceroute process and stream stdout line by line
	cmd := exec.Command("traceroute", "-n", "-q", "2", "-w", "2", "-m", "30", host)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		sendEvent("error", map[string]string{"error": err.Error()})
		return
	}
	if err := cmd.Start(); err != nil {
		// Fall back to tracepath
		cmd2 := exec.Command("tracepath", "-n", "-m", "30", host)
		out, err2 := cmd2.Output()
		if err2 != nil {
			sendEvent("error", map[string]string{"error": "traceroute/tracepath not available: " + err2.Error()})
			return
		}
		// Parse tracepath output all at once
		hops := []TracerouteHop{}
		for _, line := range strings.Split(string(out), "\n") {
			if h := parseHop(line); h != nil {
				hops = append(hops, *h)
				sendEvent("hop", h)
			}
		}
		reached := len(hops) > 0 && !hops[len(hops)-1].Timeout
		sendEvent("done", map[string]interface{}{
			"total_hops": len(hops),
			"reached":    reached,
			"host":       host,
		})
		return
	}

	// Stream stdout line by line
	hops := []TracerouteHop{}
	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		line := scanner.Text()
		if h := parseHop(line); h != nil {
			hops = append(hops, *h)
			sendEvent("hop", h)
		}
	}
	cmd.Wait()

	reached := false
	if len(hops) > 0 {
		last := hops[len(hops)-1]
		reached = !last.Timeout && (last.IP == host || last.Hostname == host)
	}
	sendEvent("done", map[string]interface{}{
		"total_hops": len(hops),
		"reached":    reached,
		"host":       host,
	})
}

type geoInfo struct {
	ASN     string
	ISP     string
	Country string
	City    string
}

func lookupGeo(ip string) *geoInfo {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("http://ip-api.com/json/" + ip + "?fields=status,country,city,isp,as")
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	var data struct {
		Status  string `json:"status"`
		Country string `json:"country"`
		City    string `json:"city"`
		ISP     string `json:"isp"`
		AS      string `json:"as"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil {
		return nil
	}
	if data.Status != "success" {
		return nil
	}
	return &geoInfo{ASN: data.AS, ISP: data.ISP, Country: data.Country, City: data.City}
}

func isAzureIP(ip string) bool {
	parsed := net.ParseIP(ip)
	if parsed == nil {
		return false
	}
	// Azure public IP ranges (major blocks)
	azureRanges := []string{
		"13.64.0.0/11", "13.96.0.0/13", "13.104.0.0/14",
		"20.0.0.0/8",   "23.96.0.0/13", "40.64.0.0/10",
		"51.0.0.0/9",   "52.0.0.0/8",   "65.52.0.0/14",
		"70.37.0.0/17", "104.40.0.0/13","137.116.0.0/15",
		"157.55.0.0/16","168.61.0.0/16","191.232.0.0/13",
	}
	for _, cidr := range azureRanges {
		_, network, err := net.ParseCIDR(cidr)
		if err == nil && network.Contains(parsed) {
			return true
		}
	}
	return false
}

// POST /api/test/ping   ?host=x
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

	// Use system ping — works on Linux inside Docker
	pingCmd := "ping"
	args := []string{"-c", "4", "-W", "3", host}
	if runtime.GOOS == "windows" {
		args = []string{"-n", "4", host}
	}

	out, err := exec.Command(pingCmd, args...).Output()
	if err != nil {
		// ping binary failed — fall back to TCP RTT measurement
		result.Error = "ICMP requires NET_ADMIN cap — falling back to TCP RTT"
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
				if v < min { min = v }
				if v > max { max = v }
				sum += v
			}
			result.MinMs = min
			result.MaxMs = max
			result.AvgMs = math.Round(sum/float64(len(rtts))*100) / 100
		}
		writeJSON(w, http.StatusOK, result)
		return
	}

	// Parse ping output
	output := string(out)
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.Contains(line, "packets transmitted") {
			// Linux: "4 packets transmitted, 4 received, 0% packet loss"
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
		if strings.Contains(line, "rtt min") || strings.Contains(line, "round-trip") {
			// Linux: "rtt min/avg/max/mdev = 1.234/2.345/3.456/0.123 ms"
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

// ─── Main ─────────────────────────────────────────────────────────────────────




// ─── AS2 Message Exchange ─────────────────────────────────────────────────────

type AS2Message struct {
	From      string `json:"from"`
	To        string `json:"to"`
	MessageID string `json:"message_id"`
	Subject   string `json:"subject"`
	Body      string `json:"body"`
	Timestamp string `json:"timestamp"`
}

type AS2Receipt struct {
	MessageID    string `json:"message_id"`
	Status       string `json:"status"`
	Disposition  string `json:"disposition"`
	ReceivedAt   string `json:"received_at"`
	From         string `json:"from"`
	OriginalBody string `json:"original_body"`
}

// POST /api/as2/send?host=x  — sends AS2 message to VM B and returns MDN receipt
func handleAS2Send(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		writeJSON(w, http.StatusOK, nil)
		return
	}
	host := r.URL.Query().Get("host")
	if host == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "host is required"})
		return
	}
	if idx := strings.LastIndex(host, ":"); idx != -1 {
		host = host[:idx]
	}
	var msg AS2Message
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid message body"})
		return
	}
	if msg.MessageID == "" {
		msg.MessageID = fmt.Sprintf("<%d@azuresphere-vma>", time.Now().UnixNano())
	}
	msg.Timestamp = time.Now().UTC().Format(time.RFC3339)

	body, _ := json.Marshal(msg)
	url := fmt.Sprintf("http://%s:9090/as2/receive", host)
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Post(url, "application/json", strings.NewReader(string(body)))
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "VM B unreachable: " + err.Error()})
		return
	}
	defer resp.Body.Close()
	var receipt AS2Receipt
	if err := json.NewDecoder(resp.Body).Decode(&receipt); err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": "invalid MDN from VM B"})
		return
	}
	writeJSON(w, http.StatusOK, receipt)
}


// GET /api/vmb/messages?host=x — proxies VM B AS2 inbox
func handleVMBMessages(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions { writeJSON(w, http.StatusOK, nil); return }
	host := r.URL.Query().Get("host")
	if host == "" { writeJSON(w, http.StatusBadRequest, map[string]string{"error": "host required"}); return }
	if idx := strings.LastIndex(host, ":"); idx != -1 { host = host[:idx] }
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(fmt.Sprintf("http://%s:9090/as2/messages", host))
	if err != nil { writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()}); return }
	defer resp.Body.Close()
	var v interface{}
	json.NewDecoder(resp.Body).Decode(&v)
	writeJSON(w, http.StatusOK, v)
}

// POST /api/vmb/clear?host=x — clears VM B AS2 inbox
func handleVMBClear(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions { writeJSON(w, http.StatusOK, nil); return }
	host := r.URL.Query().Get("host")
	if host == "" { writeJSON(w, http.StatusBadRequest, map[string]string{"error": "host required"}); return }
	if idx := strings.LastIndex(host, ":"); idx != -1 { host = host[:idx] }
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(fmt.Sprintf("http://%s:9090/as2/clear", host), "application/json", nil)
	if err != nil { writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()}); return }
	defer resp.Body.Close()
	var v interface{}
	json.NewDecoder(resp.Body).Decode(&v)
	writeJSON(w, http.StatusOK, v)
}

func main() {
	port := os.Getenv("AGENT_PORT")
	if port == "" {
		port = "8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/info",       handleInfo)
	mux.HandleFunc("/api/test/tcp",        handleTCP)
	mux.HandleFunc("/api/test/dns",        handleDNS)
	mux.HandleFunc("/api/test/tls",        handleTLS)
	mux.HandleFunc("/api/test/http",       handleHTTP)
	mux.HandleFunc("/api/test/ping",       handlePing)
	mux.HandleFunc("/api/test/traceroute", handleTraceroute)
	mux.HandleFunc("/api/as2/send",      handleAS2Send)
	mux.HandleFunc("/api/vmb/messages",  handleVMBMessages)
	mux.HandleFunc("/api/vmb/clear",     handleVMBClear)

	// Health check
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Printf("AzureSphere Agent v1.0.0 listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, mux))
}