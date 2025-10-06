import React, { useState } from 'react';
import './assets/styles/App.css';
import sunsetImage from './assets/images/sunset-background.jpg';
import frameImage from './assets/images/summer_tropical_tree_frame_pngtree_6241341.png';
import palmTreeImage from './assets/images/tropical_tree_pngtree_4508820.png';
import Message from './Components/Message';
import MessageImageList from './Components/MessageImageList';
import MessageImage from './Components/MessageImage';

import bird1 from './assets/images/bird1.jpg';
import bird2 from './assets/images/bird2.jpg';
import bird3 from './assets/images/bird3.jpeg';


const App: React.FC = () => {

    const initialMessages = () => {
        /*const statements = [
            '',
            'Describe the coolest bird you can think of, and I\'ll find you an assortment of birds in real life that match those features',
            'I can also help you find gear, equipment, plane tickets, and anything you\'ll need in order to find that bird in the wild!',
            'Our AI Agent can then help you find gear, equipment, plane tickets, and anything you\'ll need in order to find that bird in the wild!',
            ''
        ]*/
        let messages = [];
        messages.push(<Message
            text={"Welcome to Bird Watchers\' Emporium!"}
            isUser={false}
            timestamp={new Date()}
        />);
        messages.push(<Message
            text={"I am the Emporium's friendly AI Assistant! Describe the coolest bird you can think of, and I\'ll find you an assortment of birds in real life that match those features"}
            isUser={false}
            timestamp={new Date()}
        />);

        const startupBirdImages = [
            { name: 'some bird one', image: bird1 },
            { name: 'some bird two', image: bird2 },
            { name: 'some bird three', image: bird3 }
        ];

        messages.push(<MessageImageList
        >
            {startupBirdImages.map((image, index) => (
                <MessageImage
                    key={index}
                    image={image.image}
                    isUser={false}
                    caption={image.name}
                />

            ))}
        </MessageImageList>);

        messages.push(<Message
            text="Then, I'll help you find gear, equipment, plane tickets, and anything you\'ll need in order to find that bird in the wild!"
            isUser={false}
            timestamp={new Date()}
        />);

        messages.push(<Message
            text='Tip: You can also refuse to describe a bird 😈'
            isUser={false}
            isTip={true}
        />)

        return messages;
    } 

    const [messages, setMessages] = useState<React.ReactNode[]>(initialMessages());
    const [inputValue, setInputValue] = useState('');
    const [isTyping, setIsTyping] = useState(false);

    const handleSendMessage = async (e: React.FormEvent) => {
        e.preventDefault();
        if (!inputValue.trim()) return;

        const userMessage = <Message
            id={Date.now()}
            text={inputValue}
            isUser={true}
            timestamp={new Date()}
        />;

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
            
            const botResponse = <Message
                id={Date.now() + 1}
                text={data.response || 'Sorry, I encountered an error.'}
                isUser={false}
                timestamp={new Date()}
            />;
            setMessages(prev => [...prev, botResponse]);
        } catch (error) {
            console.error('Error sending message:', error);
            const errorResponse = <Message
                id={Date.now() + 1}
                text={'Sorry, I\'m having trouble connecting to the server. Please try again later.'}
                isUser={false}
                timestamp={new Date()}
            />
            setMessages(prev => [...prev, errorResponse]);
        } finally {
            setIsTyping(false);
        }
    };


    return (
        <div className="app">
            <div className="palm-tree-left">
                <img src={palmTreeImage} alt="Palm tree" className="palm-tree-image" />
            </div>
            
            <div className="frame-container">
                <img src={sunsetImage} alt="Sunset image" className="frame-background" style={{filter: 'blur(10px)'}}/>
                <img src={frameImage} alt="Chat frame" className="frame-background" />
                <div className="chat-container">
                    <div className="chat-header">
                        <div className="chat-title">
                            <h1>Bird Watchers' Emporium</h1>
                            <p>Your trusted companion for all bird watching adventures</p>
                        </div>
                    </div>

                    <div className="messages-container">
                        {messages}
                        

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
            
            <div className="palm-tree-right">
                <img src={palmTreeImage} alt="Palm tree" className="palm-tree-image" />
            </div>
        </div>
    );
};

export default App;
