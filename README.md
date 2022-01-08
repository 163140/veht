# veht
Video Edit Helper Tools



It's just a bunch of cli tools that help or/and automate a video edit operations

**blur.pl** - Blurs video gradually according to the algorithm

**transperancy.pl** - Make a video gradually transparent



Output codec: ffv1, yuva444p

Configuration: in source code

**TODO:**

**blur.pl**
1. Параллелизировать blur.
2. Переписать функции i2v и v2i. Не нравятся они мне
3. Сделать обработку ошибок
4. Сделать нормальную подготовку среды исполнения: из временной папки исключить все нелатинские символы, пробелы и знаки препинания, проверить наличие прав и свободного места для работы
5. Реализовать проверку целостности и валидности входного файла
6. Сделать счетчик прогресса операции
7. Обработка опций командной строки

**transperancy.pl**
1. Переписать, это набросок а не скрипт
