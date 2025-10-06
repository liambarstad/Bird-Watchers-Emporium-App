import React from 'react';
import '../assets/styles/MessageImage.css';

interface MessageImageProps {
    image: string;
    isUser: boolean;
    caption: string;
}

const MessageImage: React.FC<MessageImageProps> = ({ image, isUser, caption }) => {
    return (
        <div className={`message-image ${isUser ? 'user-image' : 'bot-image'}`}>
            <img src={image} alt="Bird" />
            <div className="image-caption">
                {caption}
            </div>
        </div>
    );
};

export default MessageImage;

