import React from 'react';
import { Toast, ToastBody, ToastHeader } from 'reactstrap';

interface VerificationToastProps {
  isOpen: boolean;
  toggle: () => void;
}

const VerificationToast: React.FC<VerificationToastProps> = ({ isOpen, toggle }) => {
  return (
    <Toast isOpen={isOpen} className="verification-toast">
      <ToastHeader toggle={toggle}>
        Email Verification Required
      </ToastHeader>
      <ToastBody>
        Please complete your email verification to proceed with login.
      </ToastBody>
    </Toast>
  );
};

export default VerificationToast;