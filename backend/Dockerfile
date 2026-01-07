# Use an official lightweight Python image
FROM python:3.8-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the dependencies file first to leverage Docker layer caching
COPY requirements.txt .

# Install the Python dependencies (Flask and Gunicorn)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code into the container
COPY . .

# Expose port 5000 to the outside world
EXPOSE 5000

# The command to run when the container starts.
# This uses Gunicorn to run the 'app' object from the 'app.py' file.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
