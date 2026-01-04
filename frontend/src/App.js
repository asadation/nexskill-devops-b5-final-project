import React, { useState, useEffect } from 'react';
import './App.css';

const LINK_SERVICE_URL = "/api";
const ANALYTICS_SERVICE_URL = process.env.REACT_APP_ANALYTICS_SERVICE_URL || 'http://analytics-service:4000';


function App() {
  const [url, setUrl] = useState('');
  const [shortUrl, setShortUrl] = useState('');
  const [links, setLinks] = useState([]);
  const [analytics, setAnalytics] = useState([]);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchLinks();
    fetchAnalytics();
  }, []);

  const fetchLinks = async () => {
    try {
      const response = await fetch(`${LINK_SERVICE_URL}/api/links`);
      const data = await response.json();
      setLinks(data);
    } catch (err) {
      console.error('Error fetching links:', err);
    }
  };

  const fetchAnalytics = async () => {
    try {
      const response = await fetch(`${ANALYTICS_SERVICE_URL}/api/analytics`);
      const data = await response.json();
      setAnalytics(data);
    } catch (err) {
      console.error('Error fetching analytics:', err);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setShortUrl('');

    try {
      const response = await fetch(`${LINK_SERVICE_URL}/api/shorten`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url })
      });

      const data = await response.json();
      
      if (response.ok) {
        setShortUrl(`${LINK_SERVICE_URL}${data.short_url}`);
        setUrl('');
        fetchLinks();
      } else {
        setError(data.error || 'Failed to shorten URL');
      }
    } catch (err) {
      setError('Failed to connect to server');
    }
  };

  const getClickCount = (shortCode) => {
    const analytic = analytics.find(a => a.short_code === shortCode);
    return analytic ? analytic.clicks : 0;
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>URL Shortener</h1>
      </header>

      <main className="container">
        <section className="create-section">
          <h2>Create Short URL</h2>
          <form onSubmit={handleSubmit}>
            <input
              type="url"
              placeholder="Enter your long URL"
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              required
            />
            <button type="submit">Shorten</button>
          </form>
          
          {error && <div className="error">{error}</div>}
          
          {shortUrl && (
            <div className="result">
              <p>Short URL created:</p>
              <a href={shortUrl} target="_blank" rel="noopener noreferrer">
                {shortUrl}
              </a>
            </div>
          )}
        </section>

        <section className="links-section">
          <h2>All Links</h2>
          <table>
            <thead>
              <tr>
                <th>Short Code</th>
                <th>Original URL</th>
                <th>Clicks</th>
                <th>Created</th>
              </tr>
            </thead>
            <tbody>
              {links.map((link) => (
                <tr key={link.short_code}>
                  <td>
                    <a href={`${LINK_SERVICE_URL}/${link.short_code}`} target="_blank" rel="noopener noreferrer">
                      {link.short_code}
                    </a>
                  </td>
                  <td className="url-cell">{link.original_url}</td>
                  <td>{getClickCount(link.short_code)}</td>
                  <td>{new Date(link.created_at).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      </main>
    </div>
  );
}

App.listen(3000, '0.0.0.0', () => {
  console.log('Link-service running on port 3000');
});


export default App;