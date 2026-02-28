import React from 'react';
import '../assets/styles/MessageImageList.css';

interface MessageImageListProps {
    children: React.ReactNode;
}

const MessageImageList: React.FC<MessageImageListProps> = ({ children }) => {
    return (
        <div className="message-image-list">
            <div className="image-carousel">
                {children}
            </div>
        </div>
    );
};

export default MessageImageList;


