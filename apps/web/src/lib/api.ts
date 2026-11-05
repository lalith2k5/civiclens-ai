export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1';

export const setToken = (token: string) => {
  if (typeof window !== 'undefined') localStorage.setItem('token', token);
};

export const getToken = () => {
  if (typeof window !== 'undefined') return localStorage.getItem('token');
  return null;
};

export const removeToken = () => {
  if (typeof window !== 'undefined') localStorage.removeItem('token');
};

export const logout = () => {
  removeToken();
  window.location.href = '/login';
};
