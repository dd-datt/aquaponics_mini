# Huấn luyện và xuất model TFLite cho Aquaponics
import tensorflow as tf
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.layers import Dense, GlobalAveragePooling2D
from tensorflow.keras.models import Model

# 1. Chuẩn bị dữ liệu
train_gen = ImageDataGenerator(rescale=1./255).flow_from_directory(
    'data/train', target_size=(224,224), batch_size=32, class_mode='categorical')
val_gen = ImageDataGenerator(rescale=1./255).flow_from_directory(
    'data/val', target_size=(224,224), batch_size=32, class_mode='categorical')

# 2. Fine-tune MobileNetV2
base_model = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224,224,3))
x = GlobalAveragePooling2D()(base_model.output)
output = Dense(3, activation='softmax')(x)
model = Model(inputs=base_model.input, outputs=output)

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
model.fit(train_gen, validation_data=val_gen, epochs=10)
model.save('saved_model')

# 3. Xuất model sang TFLite
converter = tf.lite.TFLiteConverter.from_saved_model('saved_model')
tflite_model = converter.convert()
with open('model.tflite', 'wb') as f:
    f.write(tflite_model)
