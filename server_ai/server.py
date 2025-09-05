from flask import Flask, request, jsonify
import tensorflow as tf
import numpy as np
import base64
from PIL import Image
import io
import os

app = Flask(__name__)
interpreter = tf.lite.Interpreter(model_path='model.tflite')
interpreter.allocate_tensors()

last_image = None
last_prediction = None

LABELS = ['healthy', 'wilting', 'yellowing']

# Dự đoán ảnh
def predict_image(img_bytes):
    img = Image.open(io.BytesIO(img_bytes)).resize((224, 224))
    arr = np.array(img) / 255.0
    arr = arr.astype(np.float32)
    arr = np.expand_dims(arr, axis=0)
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    interpreter.set_tensor(input_details[0]['index'], arr)
    interpreter.invoke()
    output = interpreter.get_tensor(output_details[0]['index'])
    label = LABELS[np.argmax(output)]
    return label

@app.route('/predict', methods=['POST'])
def predict():
    global last_image, last_prediction
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400
    img_bytes = request.files['image'].read()
    last_image = img_bytes
    label = predict_image(img_bytes)
    last_prediction = label
    return jsonify({'result': label})

@app.route('/last-image', methods=['GET'])
def last_image_api():
    if last_image:
        img_b64 = base64.b64encode(last_image).decode()
        return jsonify({'image': img_b64})
    return jsonify({'image': None})

@app.route('/last-prediction', methods=['GET'])
def last_pred_api():
    return jsonify({'result': last_prediction})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001)
