# Flutter PDF Editor
This is an example of how you can complete in app forms and rasterize them to a PDF document.

Pages can be configured with very specific fields. You can modify or add new fields.

To use, make sure to run `flutter pub get` and choose a device (mobile recommended). Then `flutter run` or debug with what ever tool you want.

The example pdf in assets demonstrates a simple pdf with different types of fields. Some can required or not. You define that in the field.

## getfields.py
This script takes in an argument for the path of the PDF file. It will extract all fields and export then into a json document for reference.
You could make it generate form fields for the Flutter project. But it is usable and good for now.

Note, the geneneration of the fields could differ depending on they're defined. You can do the insertion of fields with trial and error.
However, inserting form fields into PDF's seems like a nice to have. I used a free service to do so. I also made my fields "hidden", but you can still parse them with PyPDF2.

Website/Service Used to Apply Fields: https://www.pdfgear.com/create-fillable-pdf/

# Screenshots
<img width="300" height="1200" alt="Screenshot 1" src="https://github.com/user-attachments/assets/b930628d-7f6a-488b-b006-c01c0951d033" /> <img width="300" height="1200" alt="Screenshot 2" src="https://github.com/user-attachments/assets/87a6ef1f-a2d5-43b7-84d0-478c716157bc" />
<img width="300" height="1200" alt="Screenshot 3" src="https://github.com/user-attachments/assets/a61bc94e-e817-48b0-b617-037d0e311172" /> <img width="300" height="1200" alt="Screenshot 4" src="https://github.com/user-attachments/assets/e601324c-669b-4b6f-9135-5fb3bd8440e2" />
