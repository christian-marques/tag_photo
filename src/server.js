const express = require('express');
const fs = require('fs');
const app = express();
app.use(express.static('public'), express.json({limit: '50mb'}));
const port = 3030;

app.post('/save-image', (req, res) => {
    const base64Data = req.body.image.replace(/^data:image\/png;base64,/, "");
    fs.writeFile('image.png', base64Data, 'base64', err => {
        if (err) {
            console.error(err);
            return res.status(500).send('Error saving image');
        }
        res.send({ message: 'Image saved successfully' });
    });
});

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});