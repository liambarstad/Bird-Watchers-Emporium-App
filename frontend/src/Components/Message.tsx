import React from 'react';

interface MessageProps {
    id?: number;
    key?: string;
    text: string;
    isUser: boolean;
    isTip?: boolean;
    timestamp?: Date;
}

const Message: React.FC<MessageProps> = ({
    id,
    key,
    text,
    isUser,
    isTip,
    timestamp
 }) => {
    return (
        <div
            key={id || key}
            className={`message ${isUser ? 'user-message' : 'bot-message'}`}
        >
            <div 
                className={`message-content ${isTip ? 'tip-message' : ''}`}
            >

                <div className="message-text">{text}</div>
                {timestamp &&  
                    <div className="message-time">
                        {timestamp.toLocaleTimeString([], { 
                            hour: '2-digit', 
                            minute: '2-digit' 
                        })}
                    </div>
                }
            </div>
        </div>

    );
}

export default Message;