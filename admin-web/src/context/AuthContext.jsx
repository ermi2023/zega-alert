import { createContext, useContext, useState } from 'react';
import { api } from '../api/client';
import { TOKEN_KEY, REFRESH_KEY, USER_KEY } from '../api/client';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(() => {
    try { return JSON.parse(localStorage.getItem(USER_KEY)); } catch { return null; }
  });

  const login = async (phone, password) => {
    const data = await api.post('/auth/login', { phone, password });
    localStorage.setItem(TOKEN_KEY, data.accessToken);
    if (data.refreshToken) localStorage.setItem(REFRESH_KEY, data.refreshToken);
    localStorage.setItem(USER_KEY, JSON.stringify(data.user));
    setUser(data.user);
    return data.user;
  };

  const logout = async () => {
    // Invalidate the session on the backend (doc 3.3.3) before clearing locally.
    try {
      const refreshToken = localStorage.getItem(REFRESH_KEY);
      await api.post('/auth/logout', refreshToken ? { refreshToken } : {});
    } catch { /* best-effort: still clear locally */ }
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(REFRESH_KEY);
    localStorage.removeItem(USER_KEY);
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
