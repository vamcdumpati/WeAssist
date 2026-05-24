import React from 'react';

interface InputFieldProps {
  label: string;
  type: string;
  value: string;
  onChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
  required?: boolean;
}

const InputField: React.FC<InputFieldProps> = ({ label, type, value, onChange, required }) => {
  return (
    <div className="input-field">
      <label>
        {label}
        <input type={type} value={value} onChange={onChange} required={required} />
      </label>
    </div>
  );
};

export default InputField;