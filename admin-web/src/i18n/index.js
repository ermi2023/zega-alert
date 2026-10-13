import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import en from './en.json';
import am from './am.json';
import om from './om.json';
import ti from './ti.json';

const savedLang = localStorage.getItem('zega_lang') || 'en';

i18n.use(initReactI18next).init({
  resources: { en: { translation: en }, am: { translation: am }, om: { translation: om }, ti: { translation: ti } },
  lng: savedLang,
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
});

export default i18n;
