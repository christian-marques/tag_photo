const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
app.use(express.static('public'), express.json({limit: '50mb'}));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

const port = 3030;
const folderPath = 'fotos';

function checkFolderPath(){
    const fotosPath = path.join(__dirname, '..', folderPath);
    if (!fs.existsSync(fotosPath)) {
        fs.mkdirSync(fotosPath);
    }
}

app.post('/save-image', (req, res) => {
    checkFolderPath();

    const data = req.body.image;
    const base64Data = data.replace(/^data:image\/png;base64,/, "");
    const datetime = new Date().toISOString().replace(/:/g, '-');
    const filename = `photo-${datetime}.png`;
    const filePath = path.join(__dirname, '..', folderPath, filename);

    fs.writeFile(filePath, base64Data, 'base64', err => {
        if (err) {
            console.error(err);
            return res.status(500).send(err);
        }
        console.log('Imagem salva: ', filePath);
        res.send({ message: 'Imagem salva com sucesso: ', filename});
    });
});

app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});