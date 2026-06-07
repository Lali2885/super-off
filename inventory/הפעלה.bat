@echo off
chcp 65001 > nul
echo מתקין תלויות...
pip install -r requirements.txt --quiet
echo.
echo מפעיל שרת מלאי ביתי...
echo פתח את הדפדפן בכתובת: http://localhost:5000
echo.
python app.py
pause
