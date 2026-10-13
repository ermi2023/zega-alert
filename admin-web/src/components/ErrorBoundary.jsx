import { Component } from 'react';
import i18n from '../i18n';

export default class ErrorBoundary extends Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: 32, textAlign: 'center' }}>
          <div className="panel" style={{ maxWidth: 500, margin: '0 auto' }}>
            <h2 style={{ color: 'var(--danger)' }}>{i18n.t('error.somethingWrong')}</h2>
            <p style={{ color: 'var(--muted)', margin: '12px 0' }}>
              {this.state.error?.message || i18n.t('error.unexpectedError')}
            </p>
            <button className="btn" onClick={() => { this.setState({ hasError: false, error: null }); window.location.reload(); }}>
              {i18n.t('error.reloadPage')}
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
