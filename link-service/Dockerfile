FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Copy requirements first (better caching)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose the port your app runs on
# (Change if your app uses a different port)
EXPOSE 3000

# Run the application
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3000"]