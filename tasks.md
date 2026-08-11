Requirement: Search product via image in sales desk page

Sales desk page:
- Add a chip design for indicating whether camera is live and connected or not in top right of the screen
- "/" search should consider cameras input as well for product detection

Pre-requisite for implementing the image search feature:
- We need to fill out the product embeddings table with image vector data
- Where the images will be present - use images folder path configured in item settings
- For each product there can be 6 images: For example item sky is T101
  - T101_master.jpg
  - T101_1.jpg
  - T101_2.jpg
  - T101_3.jpg
  - T101_4.jpg
  - T101_5.jpg
- Image type can jpg jpeg png
- Add new setting block for initiate filling the embedding table with images (if embedding already available for the product delete and replace with new embeddings). provide an option to delete all training images except master after embeddings are done
- All 6 embedding should be stored separately with product id
- Only update embeddings if it has master and atleast 1 other image
- Going to use cosine smilarity for image search
- If a product image has barcode that data should be updated on product table as well

dependencies:
- google_mlkit_barcode_scanning
- onnxruntime
- image

assets:
- assets/models/vision_model_512.onnx

download the model and place it in the assets/models folder. update required changes to make this path visible for flutter

Un avoidable things:
existing functionalities should not break
unit testing not required