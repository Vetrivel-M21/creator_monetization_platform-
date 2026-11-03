package logger

import (
	"log"
	"os"
	"path/filepath"
	"time"
)

var (
	InfoLogger  *log.Logger
	ErrorLogger *log.Logger
	AuditLogger *log.Logger
)

func InitLogger() {
	logDir := "./logs"
	_ = os.MkdirAll(logDir, 0755)

	logFilePath := filepath.Join(logDir, "app.log")
	logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Printf("[Logger] Warning: Could not open file for logging: %v. Using stdout.", err)
		InfoLogger = log.New(os.Stdout, "[INFO] ", log.Ldate|log.Ltime|log.Lshortfile)
		ErrorLogger = log.New(os.Stderr, "[ERROR] ", log.Ldate|log.Ltime|log.Lshortfile)
		AuditLogger = log.New(os.Stdout, "[AUDIT] ", log.Ldate|log.Ltime)
		return
	}

	InfoLogger = log.New(logFile, "[INFO] ", log.Ldate|log.Ltime|log.Lshortfile)
	ErrorLogger = log.New(logFile, "[ERROR] ", log.Ldate|log.Ltime|log.Lshortfile)
	AuditLogger = log.New(logFile, "[AUDIT] ", log.Ldate|log.Ltime)
}

func LogAction(actorID, action, targetID, details string) {
	if AuditLogger != nil {
		AuditLogger.Printf("TIME=%s ACTOR=%s ACTION=%s TARGET=%s DETAILS=%s",
			time.Now().Format(time.RFC3339), actorID, action, targetID, details)
	}
	log.Printf("[AUDIT] ACTOR=%s ACTION=%s TARGET=%s DETAILS=%s", actorID, action, targetID, details)
}
