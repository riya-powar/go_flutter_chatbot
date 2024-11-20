package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
)

type ChatRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type ChatResponse struct {
	Choices []Choice `json:"choices"`
}

type Choice struct {
	Message Message `json:"message"`
}

// Function to enable CORS for cross-origin requests
func enableCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}

func chatHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(w)

	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if r.Method == "POST" {
		var req ChatRequest
		body, err := io.ReadAll(r.Body)
		if err != nil {
			log.Printf("Error reading request body: %v", err)
			http.Error(w, "Unable to read request body", http.StatusBadRequest)
			return
		}

		err = json.Unmarshal(body, &req)
		if err != nil {
			log.Printf("Error unmarshaling JSON: %v", err)
			http.Error(w, "Unable to parse JSON", http.StatusBadRequest)
			return
		}

		if len(req.Messages) == 0 {
			log.Println("'messages' field is empty")
			http.Error(w, "'messages' field is empty", http.StatusBadRequest)
			return
		}
		log.Printf("Received message: %s", req.Messages[0].Content)

		var imageContent string
		var textContent string
		for _, message := range req.Messages {
			if message.Content != "" && len(message.Content) >= 22 && message.Content[:22] == "data:image/;base64" {
				imageContent = message.Content
			} else if message.Content != "" {
				textContent = message.Content
			}
		}

		groqAPIKey := "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"
		url := "https://api.groq.com/openai/v1/chat/completions"

		var groqMessages []Message

		if imageContent != "" {
			imageURL := "https://example.com/your-uploaded-image.jpg"
			groqMessages = append(groqMessages, Message{
				Role:    "user",
				Content: fmt.Sprintf(`{"type":"image_url","image_url":{"url":"%s"}}`, imageURL),
			})
		}

		if textContent != "" {
			groqMessages = append(groqMessages, Message{
				Role:    "user",
				Content: textContent,
			})
		}

		// Prepare the Groq API request payload
		requestBody, err := json.Marshal(ChatRequest{
			Model:    "llama-3.2-11b-vision-preview", // Adjust the model as needed
			Messages: groqMessages,
		})
		if err != nil {
			log.Printf("Error marshaling request payload: %v", err)
			http.Error(w, "Error marshaling request payload", http.StatusInternalServerError)
			return
		}

		// Send the request to Groq API
		msg, err := http.NewRequest("POST", url, bytes.NewBuffer(requestBody))
		if err != nil {
			log.Printf("Error creating request to Groq API: %v", err)
			http.Error(w, "Error creating request", http.StatusInternalServerError)
			return
		}

		msg.Header.Set("Authorization", "Bearer "+groqAPIKey)
		msg.Header.Set("Content-Type", "application/json")

		client := &http.Client{}
		resp, err := client.Do(msg)
		if err != nil {
			log.Printf("Error sending request to Groq API: %v", err)
			http.Error(w, "Error sending request to Groq API", http.StatusInternalServerError)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			body, _ := io.ReadAll(resp.Body)
			log.Printf("Error response from Groq API: %v", body)
			http.Error(w, fmt.Sprintf("API request failed with status code: %d\n%s", resp.StatusCode, body), http.StatusInternalServerError)
			return
		}

		// Parse the response from Groq
		body2, err := io.ReadAll(resp.Body)
		if err != nil {
			log.Printf("Error reading Groq API response: %v", err)
			http.Error(w, "Error reading Groq API response", http.StatusInternalServerError)
			return
		}

		var response ChatResponse
		err = json.Unmarshal(body2, &response)
		if err != nil {
			log.Printf("Error parsing response JSON: %v", err)
			http.Error(w, "Error parsing response JSON", http.StatusInternalServerError)
			return
		}

		// Extract and send back the generated message
		if len(response.Choices) > 0 {
			generatedText := response.Choices[0].Message.Content
			log.Printf("Generated response: %s", generatedText)

			// Send the response back to the user
			responseMessage := fmt.Sprintf("%s", generatedText)
			response_ := ChatResponse{Choices: []Choice{{Message: Message{Role: "assistant", Content: responseMessage}}}}

			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response_)
		} else {
			log.Println("'choices' not found in the response.")
			http.Error(w, "'choices' not found in the response.", http.StatusInternalServerError)
		}
	} else {
		log.Println("Invalid method received: ", r.Method)
		http.Error(w, "Invalid method", http.StatusMethodNotAllowed)
	}
}

func main() {
	http.HandleFunc("/chat", chatHandler)

	fmt.Println("Starting Go server on :8080...")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
