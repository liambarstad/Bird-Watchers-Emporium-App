import React, { useState } from 'react';
import './App.css';

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

    // Simulate bot response
    setTimeout(() => {
      const botResponse: Message = {
        id: Date.now() + 1,
        text: generateBotResponse(inputValue),
        isUser: false,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, botResponse]);
      setIsTyping(false);
    }, 1000 + Math.random() * 2000);
  };

  const generateBotResponse = (userInput: string): string => {
    const responses = [
      "That's a great question about bird watching! 🦅",
      "I'd be happy to help you find the perfect binoculars for your bird watching adventures! 🔭",
      "Have you considered our premium bird identification guides? 📚",
      "The best time for bird watching is usually early morning or late afternoon! 🌅",
      "We have excellent recommendations for bird watching locations in your area! 🗺️",
      "Our expert team can help you choose the right equipment for your skill level! 🎯",
      "Bird watching is such a rewarding hobby - you're in for a treat! 🎉",
      "We have some amazing bird watching tours coming up - would you like to know more? 🚶‍♂️"
    ];
    return responses[Math.floor(Math.random() * responses.length)];
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
