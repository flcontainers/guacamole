FROM amd64/python:3-alpine

# Install requirements
WORKDIR /usr/src/app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy application sources
COPY src .

# Run the application
ENV FLASK_APP=app.py
CMD [ "flask", "run" ]
