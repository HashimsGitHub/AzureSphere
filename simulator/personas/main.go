package main

import (
	"encoding/binary"
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

// ─── Persona definition ───────────────────────────────────────────────────────

type Persona struct {
	Name     string `json:"name"`
	Protocol string `json:"protocol"`
	Port     int    `json:"port"`
	Banner   string `json:"banner"`
}

type ConnectionEvent struct {
	Time     string `json:"time"`
	Persona  string `json:"persona"`
	Port     int    `json:"port"`
	RemoteIP string `json:"remote_ip"`
	Protocol string `json:"protocol"`
}

// ─── Global state ─────────────────────────────────────────────────────────────

var (
	personas      []Persona
	connLog       []ConnectionEvent
	connMu        sync.Mutex
	startTime     = time.Now()
	totalConnects int64
)

func logConn(persona string, port int, protocol, remote string) {
	connMu.Lock()
	defer connMu.Unlock()
	totalConnects++
	ev := ConnectionEvent{
		Time:     time.Now().UTC().Format(time.RFC3339),
		Persona:  persona,
		Port:     port,
		Protocol: protocol,
		RemoteIP: remote,
	}
	connLog = append([]ConnectionEvent{ev}, connLog...)
	if len(connLog) > 500 {
		connLog = connLog[:500]
	}
	log.Printf("[%s] connection from %s → %s :%d", protocol, remote, persona, port)
}

// ─── Protocol handlers ────────────────────────────────────────────────────────

func handleSQL(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "SQL/TDS", conn.RemoteAddr().String())
	// TDS Pre-Login response — enough for VM A agent to detect SQL Server
	// TokenType=0x04 (PreLogin), Version=16.0.4120.1 (SQL Server 2022)
	prelogin := []byte{
		0x04, 0x01, 0x00, 0x2B, 0x00, 0x00, 0x01, 0x00,
		0x00, 0x00, 0x1A, 0x00, 0x06, // VERSION offset+len
		0x01, 0x00, 0x20, 0x00, 0x01, // ENCRYPTION offset+len
		0x02, 0x00, 0x21, 0x00, 0x01, // INSTOPT
		0x03, 0x00, 0x22, 0x00, 0x04, // THREADID
		0x04, 0x00, 0x26, 0x00, 0x01, // MARS
		0xFF,                          // terminator
		0x10, 0x00, 0x07, 0x8B, 0x00, 0x00, // version: 16.0.1931
		0x02,                          // encryption: not supported
		0x00,                          // instance
		0x00, 0x00, 0x00, 0x00,        // thread id
		0x00,                          // MARS off
	}
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	conn.Read(make([]byte, 1024)) // read client pre-login
	conn.Write(prelogin)
}

func handlePostgres(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "PostgreSQL", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	conn.Read(make([]byte, 1024)) // read startup message
	// Authentication request — MD5 password (type R, len 12, auth type 5)
	msg := []byte{'R', 0, 0, 0, 12, 0, 0, 0, 5, 0xDE, 0xAD, 0xBE, 0xEF}
	conn.Write(msg)
}

func handleFTP(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "FTP", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(10 * time.Second))
	banner := fmt.Sprintf("220 %s FTP Server Ready (AzureSphere Simulator)\r\n", persona.Name)
	conn.Write([]byte(banner))
	// Respond to USER command
	buf := make([]byte, 256)
	n, _ := conn.Read(buf)
	if n > 0 && strings.HasPrefix(string(buf[:n]), "USER") {
		conn.Write([]byte("331 Password required\r\n"))
		conn.Read(buf) // PASS
		conn.Write([]byte("230 Login successful — AzureSphere Simulator\r\n"))
	}
}

func handleRabbitMQ(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "AMQP/RabbitMQ", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	buf := make([]byte, 8)
	conn.Read(buf) // AMQP\x00\x00\x09\x01 protocol header

	// AMQP 0-9-1 Connection.Start frame
	// Frame type=1 (method), channel=0, class=10 (connection), method=10 (start)
	capabilities := `{"publisher_confirms":true,"exchange_exchange_bindings":true,"basic.nack":true,"consumer_cancel_notify":true,"connection.blocked":true,"consumer_priorities":true,"authentication_failure_close":true,"per_consumer_qos":true,"direct_reply_to":true}`
	serverProps := fmt.Sprintf(
		"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"+
			"\x07product\x53\x00\x00\x00\x08RabbitMQ"+
			"\x07version\x53\x00\x00\x00\x05%s"+
			"\x08platform\x53\x00\x00\x00\x13Erlang/OTP 26.0"+
			"\x0Ccapabilities\x46%s",
		"3.12.6", capabilities)
	_ = serverProps

	// Simplified valid Connection.Start
	payload := []byte{
		0x00, 0x0A, 0x00, 0x0A, // class=10, method=10
		0x00, 0x09,             // version major=0, minor=9
		// server properties (empty table for simplicity)
		0x00, 0x00, 0x00, 0x00,
		// mechanisms
		0x00, 0x00, 0x00, 0x05, 'P', 'L', 'A', 'I', 'N',
		// locales
		0x00, 0x00, 0x00, 0x05, 'e', 'n', '_', 'U', 'S',
	}
	frame := make([]byte, 7+len(payload)+1)
	frame[0] = 1 // type: method
	binary.BigEndian.PutUint16(frame[1:3], 0)
	binary.BigEndian.PutUint32(frame[3:7], uint32(len(payload)))
	copy(frame[7:], payload)
	frame[7+len(payload)] = 0xCE // frame end
	conn.Write(frame)
}

func handleSAPHANA(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "SAP HANA", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	conn.Read(make([]byte, 1024))
	// HANA SQL port greeting — simplified
	greeting := []byte{
		0x00, 0x00, 0x00, 0x08, // length
		0xFF, 0xFF, 0xFF, 0xFF, // version indicator
	}
	conn.Write(greeting)
}

func handleWebMethods(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "webMethods/HTTP", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(10 * time.Second))
	buf := make([]byte, 4096)
	conn.Read(buf)
	resp := "HTTP/1.1 200 OK\r\n" +
		"Server: webMethods Integration Server 10.15\r\n" +
		"Content-Type: text/html\r\n" +
		"X-Powered-By: Software AG webMethods\r\n" +
		"Connection: close\r\n\r\n" +
		"<html><body><h1>webMethods Integration Server</h1>" +
		"<p>AzureSphere Simulator — Persona active on port " +
		strconv.Itoa(persona.Port) + "</p></body></html>"
	conn.Write([]byte(resp))
}

func handleSMB(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "SMB", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	conn.Read(make([]byte, 1024))
	// SMB2 negotiate response header (minimal)
	smb2Header := []byte{
		0x00, 0x00, 0x00, 0x54, // NetBIOS length
		0xFE, 0x53, 0x4D, 0x42, // SMB2 magic
		0x40, 0x00,             // header size
		0x00, 0x00,             // credit charge
		0x00, 0x00, 0x00, 0x00, // status
		0x00, 0x00,             // command: negotiate
		0x01, 0x00,             // credits granted
		0x01, 0x00, 0x00, 0x00, // flags: response
		0x00, 0x00, 0x00, 0x00, // next command
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // message id
		0x00, 0x00, 0x00, 0x00, // process id
		0x00, 0x00, 0x00, 0x00, // tree id
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // session id
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // signature
		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	}
	conn.Write(smb2Header)
}

func handleGenericTCP(conn net.Conn, persona Persona) {
	defer conn.Close()
	logConn(persona.Name, persona.Port, "TCP", conn.RemoteAddr().String())
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	banner := persona.Banner
	if banner == "" {
		banner = fmt.Sprintf("220 %s AzureSphere Simulator ready on port %d\r\n",
			persona.Name, persona.Port)
	}
	conn.Write([]byte(banner))
}

// ─── Listener factory ─────────────────────────────────────────────────────────

func startListener(persona Persona) {
	addr := fmt.Sprintf(":%d", persona.Port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		log.Printf("[ERROR] cannot listen on %d for %s: %v", persona.Port, persona.Name, err)
		return
	}
	log.Printf("[START] %s persona on :%d (%s)", persona.Name, persona.Port, persona.Protocol)

	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Printf("[ERROR] accept on %d: %v", persona.Port, err)
			continue
		}
		go func(c net.Conn) {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("[RECOVER] %s: %v", persona.Name, r)
				}
			}()
			switch strings.ToUpper(persona.Protocol) {
			case "SQL", "MSSQL", "SQLSERVER":
				handleSQL(c, persona)
			case "POSTGRES", "POSTGRESQL":
				handlePostgres(c, persona)
			case "FTP":
				handleFTP(c, persona)
			case "RABBITMQ", "AMQP":
				handleRabbitMQ(c, persona)
			case "HANA", "SAPHANA":
				handleSAPHANA(c, persona)
			case "WEBMETHODS", "WEBM":
				handleWebMethods(c, persona)
			case "SMB":
				handleSMB(c, persona)
			default:
				handleGenericTCP(c, persona)
			}
		}(conn)
	}
}

// ─── Status API ───────────────────────────────────────────────────────────────

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(v)
}


// ─── AS2 Message Store ────────────────────────────────────────────────────────

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

var (
	as2Messages []AS2Message
	as2Mu       sync.Mutex
)

// POST /as2/receive — receives AS2 message from VM A, returns MDN receipt
func as2ReceiveHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	var msg AS2Message
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	msg.Timestamp = time.Now().UTC().Format(time.RFC3339)

	as2Mu.Lock()
	as2Messages = append([]AS2Message{msg}, as2Messages...)
	if len(as2Messages) > 200 {
		as2Messages = as2Messages[:200]
	}
	as2Mu.Unlock()

	hostname, _ := os.Hostname()
	log.Printf("[AS2] Message received from %s: %s", msg.From, msg.Subject)

	receipt := AS2Receipt{
		MessageID:    msg.MessageID,
		Status:       "processed",
		Disposition:  "automatic-action/MDN-sent-automatically; processed",
		ReceivedAt:   msg.Timestamp,
		From:         hostname,
		OriginalBody: msg.Body,
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(receipt)
}

// GET /as2/messages — returns received AS2 messages
func as2MessagesHandler(w http.ResponseWriter, r *http.Request) {
	as2Mu.Lock()
	defer as2Mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(as2Messages)
}

// DELETE /as2/messages — clears AS2 message store
func as2ClearHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST required", http.StatusMethodNotAllowed)
		return
	}
	as2Mu.Lock()
	cleared := len(as2Messages)
	as2Messages = []AS2Message{}
	as2Mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(map[string]interface{}{"cleared": cleared})
}

func main() {
	// Load personas from environment — one per env var PERSONA_n=name:protocol:port:banner
	// e.g. PERSONA_1=SQL Server:SQL:1433:
	//      PERSONA_2=PostgreSQL:POSTGRES:5432:
	//      PERSONA_3=FTP Server:FTP:21:220 Welcome
	for i := 1; i <= 50; i++ {
		val := os.Getenv(fmt.Sprintf("PERSONA_%d", i))
		if val == "" {
			continue
		}
		parts := strings.SplitN(val, ":", 4)
		if len(parts) < 3 {
			log.Printf("[WARN] invalid PERSONA_%d: %s", i, val)
			continue
		}
		port, err := strconv.Atoi(strings.TrimSpace(parts[2]))
		if err != nil {
			log.Printf("[WARN] invalid port in PERSONA_%d: %s", i, parts[2])
			continue
		}
		banner := ""
		if len(parts) == 4 {
			banner = parts[3]
		}
		p := Persona{
			Name:     strings.TrimSpace(parts[0]),
			Protocol: strings.TrimSpace(parts[1]),
			Port:     port,
			Banner:   banner,
		}
		personas = append(personas, p)
	}

	if len(personas) == 0 {
		log.Println("[WARN] No PERSONA_n env vars found — using defaults")
		personas = []Persona{
			{Name: "SQL Server",    Protocol: "SQL",        Port: 1433},
			{Name: "PostgreSQL",    Protocol: "POSTGRES",   Port: 5432},
			{Name: "FTP Server",    Protocol: "FTP",        Port: 21},
			{Name: "RabbitMQ",      Protocol: "RABBITMQ",   Port: 5672},
			{Name: "SAP HANA",      Protocol: "HANA",       Port: 30015},
			{Name: "webMethods IS", Protocol: "WEBMETHODS", Port: 5555},
			{Name: "SMB Share",     Protocol: "SMB",        Port: 445},
		}
	}

	// Start all persona listeners
	for _, p := range personas {
		go startListener(p)
	}

	// Status API — used by VM B dashboard
	apiPort := os.Getenv("API_PORT")
	if apiPort == "" {
		apiPort = "9090"
	}

	mux := http.NewServeMux()

	mux.HandleFunc("/api/personas", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, personas)
	})

	mux.HandleFunc("/api/connections", func(w http.ResponseWriter, r *http.Request) {
		connMu.Lock()
		defer connMu.Unlock()
		writeJSON(w, connLog)
	})

	// Reset endpoint — clears in-memory log only, preserves totalConnects counter
	mux.HandleFunc("/api/connections/reset", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "POST required", http.StatusMethodNotAllowed)
			return
		}
		connMu.Lock()
		cleared := len(connLog)
		connLog = []ConnectionEvent{}
		connMu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"cleared":   cleared,
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
		log.Printf("[RESET] connection log cleared (%d entries removed)", cleared)
	})

	mux.HandleFunc("/api/status", func(w http.ResponseWriter, r *http.Request) {
		connMu.Lock()
		logLen := len(connLog)
		total := totalConnects
		connMu.Unlock()
		hostname, _ := os.Hostname()
		writeJSON(w, map[string]interface{}{
			"hostname":       hostname,
			"uptime":         time.Since(startTime).Round(time.Second).String(),
			"persona_count":  len(personas),
			"total_connects": total,
			"log_entries":    logLen,
			"timestamp":      time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/as2/receive",  as2ReceiveHandler)
	mux.HandleFunc("/as2/messages", as2MessagesHandler)
	mux.HandleFunc("/as2/clear",    as2ClearHandler)

	log.Printf("VM B Simulator — %d personas active", len(personas))
	log.Printf("Status API on :%s", apiPort)
	for _, p := range personas {
		log.Printf("  %-20s %s → :%d", p.Name, p.Protocol, p.Port)
	}
	log.Fatal(http.ListenAndServe(":"+apiPort, mux))
}