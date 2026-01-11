const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const config = require('./config');

const app = express();
app.use(cors());
app.use(express.json());



const pool = new Pool(config.database);


async function initDb() {
    const client = await pool.connect();
    try {
        await client.query(`
            CREATE TABLE IF NOT EXISTS analytics (
                id SERIAL PRIMARY KEY,
                short_code VARCHAR(10) NOT NULL,
                clicked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log('Analytics table initialized');
    } finally {
        client.release();
    }
}

app.get('/health', (req, res) => {
    res.json({ status: 'healthy' });
});

app.post('/api/track', async (req, res) => {
    const { short_code } = req.body;
    
    if (!short_code) {
        return res.status(400).json({ error: 'short_code is required' });
    }
    
    try {
        await pool.query(
            'INSERT INTO analytics (short_code) VALUES ($1)',
            [short_code]
        );
        res.status(201).json({ message: 'Click tracked' });
    } catch (error) {
        console.error('Error tracking click:', error);
        res.status(500).json({ error: 'Failed to track click' });
    }
});

app.get('/api/analytics/:short_code', async (req, res) => {
    const { short_code } = req.params;
    
    try {
        const result = await pool.query(
            'SELECT COUNT(*) as clicks FROM analytics WHERE short_code = $1',
            [short_code]
        );
        res.json({ short_code, clicks: parseInt(result.rows[0].clicks) });
    } catch (error) {
        console.error('Error fetching analytics:', error);
        res.status(500).json({ error: 'Failed to fetch analytics' });
    }
});

app.get('/api/analytics', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT short_code, COUNT(*) as clicks 
            FROM analytics 
            GROUP BY short_code 
            ORDER BY clicks DESC
        `);
        res.json(result.rows.map(row => ({
            short_code: row.short_code,
            clicks: parseInt(row.clicks)
        })));
    } catch (error) {
        console.error('Error fetching all analytics:', error);
        res.status(500).json({ error: 'Failed to fetch analytics' });
    }
});

initDb().then(() => {
    app.listen(config.port, '0.0.0.0', () => {
        console.log(`Analytics service running on port ${config.port}`);
    });
});