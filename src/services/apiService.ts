const API_BASE = 'https://emergency-tracker-api.onrender.com';

export interface RegisterPayload {
  name: string;
  email: string;
  phone: string;
  password: string;
  role: string;
}

export interface LoginPayload {
  email: string;
  password: string;
}

export interface UserResponse {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: string;
}

export interface MessageResponse {
  message: string;
  data?: { [key: string]: any } | null;
}

function handleResponse(res: Response): Promise<any> {
  return res.text().then(function(text: string) {
    var json: any = null;
    try { json = JSON.parse(text); } catch(e) {}

    if (!res.ok) {
      if (res.status === 500) {
        throw new Error('The server encountered an error. Please try again later or contact support.');
      }
      if (json) {
        if (Array.isArray(json.detail)) {
          var msgs = json.detail.map(function(d: any) { return d.msg; }).join(', ');
          throw new Error(msgs || ('Request failed with status ' + res.status));
        }
        throw new Error(json.detail || json.message || ('Request failed with status ' + res.status));
      }
      throw new Error('Request failed with status ' + res.status);
    }
    return json || {};
  });
}


export const apiService = {
  /** POST /web/auth/register */
  register: function(payload: RegisterPayload): Promise<MessageResponse> {
    return fetch(API_BASE + '/web/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(handleResponse);
  },

  /** POST /web/auth/login */
  login: function(payload: LoginPayload): Promise<MessageResponse> {
    return fetch(API_BASE + '/web/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    }).then(handleResponse);
  },

  /** GET /web/auth/user/{user_id} */
  getUser: function(userId: string): Promise<UserResponse> {
    return fetch(API_BASE + '/web/auth/user/' + userId).then(handleResponse);
  },
};
