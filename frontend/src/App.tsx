import React, { useState } from 'react';
import './assets/styles/App.css';

interface Message {
    id: number;
    text: string;
    isUser: boolean;
    timestamp: Date;
}

const App: React.FC = () => {
    const [messages, setMessages] = useState<Message[]>([
        {
            id: 1,
            text: "Welcome to Bird Watchers' Emporium! 🐦 How can I help you with your bird watching needs today?",
            isUser: false,
            timestamp: new Date()
        }
    ]);
    const [inputValue, setInputValue] = useState('');
    const [isTyping, setIsTyping] = useState(false);

    const handleSendMessage = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!inputValue.trim()) return;

        const userMessage: Message = {
            id: Date.now(),
            text: inputValue,
            isUser: true,
            timestamp: new Date()
        };

        setMessages(prev => [...prev, userMessage]);
        setInputValue('');
        setIsTyping(true);

        try {
            // Make API call to backend
            const response = await fetch(`${process.env.REACT_APP_API_URL}/query`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ message: inputValue }),
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            const botResponse: Message = {
                id: Date.now() + 1,
                text: data.response || 'Sorry, I encountered an error.',
                isUser: false,
                timestamp: new Date()
            };
            setMessages(prev => [...prev, botResponse]);
        } catch (error) {
            console.error('Error sending message:', error);
            const errorResponse: Message = {
                id: Date.now() + 1,
                text: 'Sorry, I\'m having trouble connecting to the server. Please try again later.',
                isUser: false,
                timestamp: new Date()
            };
            setMessages(prev => [...prev, errorResponse]);
        } finally {
            setIsTyping(false);
        }
    };


    return (
        <div className="app">
            <div className="chat-container">
                <div className="chat-header">
                    <h1>🐦 Bird Watchers' Emporium</h1>
                    <p>Your trusted companion for all bird watching adventures</p>
                </div>

                <div className="messages-container">
                    {messages.map((message) => (
                        <div
                            key={message.id}
                            className={`message ${message.isUser ? 'user-message' : 'bot-message'}`}
                        >
                            <div className="message-content">
                                <div className="message-text">{message.text}</div>
                                <div className="message-time">
                                    {message.timestamp.toLocaleTimeString([], { 
                                        hour: '2-digit', 
                                        minute: '2-digit' 
                                    })}
                                </div>
                            </div>
                        </div>
                    ))}

                    {isTyping && (
                        <div className="message bot-message">
                            <div className="message-content">
                                <div className="typing-indicator">
                                    <span></span>
                                    <span></span>
                                    <span></span>
                                </div>
                            </div>
                        </div>
                    )}
                </div>

                <form onSubmit={handleSendMessage} className="input-form">
                    <div className="input-container">
                        <input
                            type="text"
                            value={inputValue}
                            onChange={(e) => setInputValue(e.target.value)}
                            placeholder="Ask about bird watching equipment, locations, or tips..."
                            className="message-input"
                        />
                        <button type="submit" className="send-button" disabled={!inputValue.trim()}>
                            Send
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default App;
