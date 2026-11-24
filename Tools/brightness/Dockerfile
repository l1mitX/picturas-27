FROM python:3.11-slim

WORKDIR /app

COPY ./brightness .

COPY ./effects/brightness.py ./effects/brightness.py

COPY ./utils ./utils
RUN pip install --no-cache-dir -r ./utils/requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

CMD [ "python","-u", "brightness.py"]