declare module 'firebase/app' {
  export function initializeApp(config: any, name?: string): any;
  export function getApps(): any[];
  export function getApp(name?: string): any;
}

declare module 'firebase/messaging' {
  export function getMessaging(app?: any): any;
  export function getToken(messaging: any, options?: any): Promise<string>;
  export function deleteToken(messaging: any): Promise<boolean>;
  export function onMessage(messaging: any, nextOrObserver: (payload: any) => void): () => void;
  export function isSupported(): Promise<boolean>;
}

