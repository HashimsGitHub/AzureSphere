package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
)

type Persona struct {
	Name     string
	Protocol string
	Port     int
	Banner   string
}

type ConnectionRecord struct {
	Time      string `json:"time"`
	RemoteIP  string `json:"remote_ip"`
	Persona   string `json:"persona"`
	Protocol  string `json:"protocol"`
	Port      int    `json:"port"`
	UserAgent string `json:"user_agent,omitempty"`
}

type PersonaServer struct {
	personas        []Persona
	listeners       []net.Listener
	connectionLog   []ConnectionRecord
	logMutex        sync.RWMutex
	startTime       time.Time
	totalConnects   int
	connMutex       sync.Mutex
	localIPs        map[string]bool
}

func NewPersonaServer() *PersonaServer {
	ps := &PersonaServer{
		personas:      make([]Persona, 0),
		listeners:     make([]net.Listener, 0),
		connectionLog: make([]ConnectionRecord, 0),
		startTime:     time.Now(),
		localIPs:      make(map[string]bool),
	}
	ps.detectLocalIPs()
	return ps
}

func (ps *PersonaServer) detectLocalIPs() {
	// Add standard local IPs
	ps.localIPs["127.0.0.1"] = true
	ps.localIPs["::1"] = true
	ps.localIPs["localhost"] = true
	
	// Get all network interfaces
	addrs, err := net.InterfaceAddrs()
	if err == nil {
		for _, addr := range addrs {
			if ipnet, ok := addr.(*net.IPNet); ok {
				if ipnet.IP.IsLoopback() || ipnet.IP.IsPrivate() {
					ps.localIPs[ipnet.IP.String()] = true
				}
			}
		}
	}
	
	// Add Docker bridge networks
	for i := 17; i <= 20; i++ {
		ps.localIPs[fmt.Sprintf("172.%d.0.1", i)] = true
	}
}

func (ps *PersonaServer) isLocalIP(ip string) bool {
	// Strip port if present
	if idx := strings.Index(ip, ":"); idx != -1 {
		ip = ip[:idx]
	}
	return ps.localIPs[ip]
}

func (ps *PersonaServer) addConnection(remoteIP string, persona Persona) {
	ps.connMutex.Lock()
	defer ps.connMutex.Unlock()
	
	// Skip recording local connections
	if ps.isLocalIP(remoteIP) {
		log.Printf("Skipping local connection from %s to %s (port %d)", remoteIP, persona.Name, persona.Port)
		return
	}
	
	ps.totalConnects++
	
	record := ConnectionRecord{
		Time:     time.Now().Format(time.RFC3339),
		RemoteIP: remoteIP,
		Persona:  persona.Name,
		Protocol: persona.Protocol,
		Port:     persona.Port,
	}
	
	ps.logMutex.Lock()
	ps.connectionLog = append([]ConnectionRecord{record}, ps.connectionLog...)
	// Keep last 1000 records
	if len(ps.connectionLog) > 1000 {
		ps.connectionLog = ps.connectionLog[:1000]
	}
	ps.logMutex.Unlock()
	
	log.Printf("✅ REAL CONNECTION: %s from %s to %s (port %d)", 
		persona.Protocol, remoteIP, persona.Name, persona.Port)
}

func (ps *PersonaServer) handleConnection(conn net.Conn, persona Persona) {
	defer conn.Close()
	
	remoteAddr := conn.RemoteAddr().String()
	log.Printf("Incoming connection on port %d from %s", persona.Port, remoteAddr)
	
	// Record the connection (only if not local)
	ps.addConnection(remoteAddr, persona)
	
	// Send banner if configured
	if persona.Banner != "" {
		conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
		conn.Write([]byte(persona.Banner + "\n"))
	}
	
	// For protocol-specific handling
	switch persona.Protocol {
	case "SQL":
		ps.handleSQL(conn, persona)
	case "POSTGRES":
		ps.handlePostgres(conn, persona)
	case "FTP":
		ps.handleFTP(conn, persona)
	case "RABBITMQ":
		ps.handleRabbitMQ(conn, persona)
	case "HANA":
		ps.handleHANA(conn, persona)
	case "WEBMETHODS":
		ps.handleWebMethods(conn, persona)
	case "SMB":
		ps.handleSMB(conn, persona)
	default:
		ps.handleGenericTCP(conn, persona)
	}
}

func (ps *PersonaServer) handleGenericTCP(conn net.Conn, persona Persona) {
	// Read and echo for TCP test
	reader := bufio.NewReader(conn)
	for {
		conn.SetReadDeadline(time.Now().Add(30 * time.Second))
		message, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		conn.Write([]byte("ECHO: " + message))
	}
}

func (ps *PersonaServer) handleSQL(conn net.Conn, persona Persona) {
	// Simulate SQL Server pre-login response
	response := []byte{
		0x04, 0x01, 0x00, 0x25, 0x00, 0x00, 0x01, 0x00, // PRELOGIN response
	}
	conn.Write(response)
	time.Sleep(100 * time.Millisecond)
	conn.Write([]byte("Microsoft SQL Server 2022 - AzureSphere Edition\r\n"))
}

func (ps *PersonaServer) handlePostgres(conn net.Conn, persona Persona) {
	// Send PostgreSQL startup message
	conn.Write([]byte("NPostgreSQL 15.3 on x86_64-pc-linux-gnu\r\n"))
}

func (ps *PersonaServer) handleFTP(conn net.Conn, persona Persona) {
	conn.Write([]byte("220 AzureSphere FTP Server ready\r\n"))
	reader := bufio.NewReader(conn)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		if strings.HasPrefix(strings.ToUpper(line), "QUIT") {
			conn.Write([]byte("221 Goodbye\r\n"))
			break
		}
		conn.Write([]byte("502 Command not implemented\r\n"))
	}
}

func (ps *PersonaServer) handleRabbitMQ(conn net.Conn, persona Persona) {
	// AMQP 0-9-1 protocol header
	conn.Write([]byte{0x41, 0x4d, 0x51, 0x50, 0x00, 0x09, 0x01, 0x00})
}

func (ps *PersonaServer) handleHANA(conn net.Conn, persona Persona) {
	conn.Write([]byte("SAP HANA Database 2.00.070.00\r\n"))
}

func (ps *PersonaServer) handleWebMethods(conn net.Conn, persona Persona) {
	conn.Write([]byte("HTTP/1.1 200 OK\r\nServer: webMethods IS 10.15\r\n\r\n"))
}

func (ps *PersonaServer) handleSMB(conn net.Conn, persona Persona) {
	// SMB protocol negotiation response
	conn.Write([]byte{0x00, 0x00, 0x00, 0x2f, 0xfe, 0x53, 0x4d, 0x42})
}

func (ps *PersonaServer) startPersona(persona Persona) error {
	listener, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", persona.Port))
	if err != nil {
		return fmt.Errorf("failed to listen on port %d: %v", persona.Port, err)
	}
	
	ps.listeners = append(ps.listeners, listener)
	
	log.Printf("🚀 Started %s persona '%s' on port %d", persona.Protocol, persona.Name, persona.Port)
	
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				log.Printf("Accept error on port %d: %v", persona.Port, err)
				return
			}
			go ps.handleConnection(conn, persona)
		}
	}()
	
	return nil
}

func (ps *PersonaServer) loadPersonasFromEnv() {
	for i := 1; i <= 100; i++ {
		envKey := fmt.Sprintf("PERSONA_%d", i)
		personaStr := os.Getenv(envKey)
		if personaStr == "" {
			continue
		}
		
		// Format: "Name:PROTOCOL:PORT:Banner"
		parts := strings.SplitN(personaStr, ":", 4)
		if len(parts) < 3 {
			log.Printf("Invalid persona format for %s: %s (expected Name:PROTOCOL:PORT:Banner)", envKey, personaStr)
			continue
		}
		
		name := parts[0]
		protocol := strings.ToUpper(parts[1])
		port, err := strconv.Atoi(parts[2])
		if err != nil {
			log.Printf("Invalid port for %s: %s", envKey, parts[2])
			continue
		}
		
		banner := ""
		if len(parts) >= 4 {
			banner = parts[3]
		}
		
		persona := Persona{
			Name:     name,
			Protocol: protocol,
			Port:     port,
			Banner:   banner,
		}
		
		ps.personas = append(ps.personas, persona)
		
		if err := ps.startPersona(persona); err != nil {
			log.Printf("Failed to start persona %s: %v", name, err)
		}
	}
}

// API Handlers
func (ps *PersonaServer) statusHandler(w http.ResponseWriter, r *http.Request) {
	hostname, _ := os.Hostname()
	uptime := time.Since(ps.startTime)
	
	response := map[string]interface{}{
		"hostname":       hostname,
		"persona_count":  len(ps.personas),
		"total_connects": ps.totalConnects,
		"uptime":         formatDuration(uptime),
		"status":         "healthy",
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ps *PersonaServer) personasHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ps.personas)
}

func (ps *PersonaServer) connectionsHandler(w http.ResponseWriter, r *http.Request) {
	ps.logMutex.RLock()
	defer ps.logMutex.RUnlock()
	
	// Return only non-local connections
	filtered := make([]ConnectionRecord, 0)
	for _, conn := range ps.connectionLog {
		if !ps.isLocalIP(conn.RemoteIP) {
			filtered = append(filtered, conn)
		}
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(filtered)
}

func (ps *PersonaServer) resetConnectionsHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}
	
	ps.logMutex.Lock()
	cleared := len(ps.connectionLog)
	ps.connectionLog = make([]ConnectionRecord, 0)
	ps.logMutex.Unlock()
	
	ps.connMutex.Lock()
	ps.totalConnects = 0
	ps.connMutex.Unlock()
	
	log.Printf("Connection log cleared (%d entries)", cleared)
	
	response := map[string]interface{}{
		"cleared": cleared,
		"status":  "ok",
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (ps *PersonaServer) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

func formatDuration(d time.Duration) string {
	hours := int(d.Hours())
	minutes := int(d.Minutes()) % 60
	seconds := int(d.Seconds()) % 60
	
	if hours > 0 {
		return fmt.Sprintf("%dh%dm", hours, minutes)
	}
	if minutes > 0 {
		return fmt.Sprintf("%dm%ds", minutes, seconds)
	}
	return fmt.Sprintf("%ds", seconds)
}

func main() {
	log.Println("Starting AzureSphere Destination Host Persona API...")
	
	server := NewPersonaServer()
	server.loadPersonasFromEnv()
	
	if len(server.personas) == 0 {
		log.Println("⚠️  WARNING: No personas configured. Set PERSONA_n environment variables.")
	}
	
	// API routes
	http.HandleFunc("/api/status", server.statusHandler)
	http.HandleFunc("/api/personas", server.personasHandler)
	http.HandleFunc("/api/connections", server.connectionsHandler)
	http.HandleFunc("/api/connections/reset", server.resetConnectionsHandler)
	http.HandleFunc("/health", server.healthHandler)
	
	port := os.Getenv("API_PORT")
	if port == "" {
		port = "9090"
	}
	
	log.Printf("Persona API listening on :%s", port)
	log.Printf("Active personas: %d", len(server.personas))
	
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal("Failed to start API server:", err)
	}
}