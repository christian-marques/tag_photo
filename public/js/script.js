// Função para inicializar a câmera usando a API do Capacitor ou a API Web padrão
async function initializeCamera() {
  let stream;
  if (window.Capacitor && Capacitor.isNativePlatform()) {
      // Usando o plugin Capacitor Camera
      return;  // Não precisa inicializar o stream, pois a foto será tirada diretamente pelo Capacitor
  } else {
      // Usando a API Web padrão
      try {
          stream = await navigator.mediaDevices.getUserMedia({ video: true });
          const videoElement = document.getElementById('video');
          videoElement.srcObject = stream;
      } catch (error) {
          console.error('Erro ao acessar a câmera:', error);
      }
  }
}

// Função para capturar imagem
async function captureImage() {
  if (window.Capacitor && Capacitor.isNativePlatform()) {
      // Usando o plugin Capacitor Camera
      const { Camera, CameraResultType } = Capacitor.Plugins;
      const image = await Camera.getPhoto({
          quality: 90,
          allowEditing: false,
          resultType: CameraResultType.DataUrl
      });
      return image.dataUrl;
  } else {
      // Usando a API Web padrão
      const videoElement = document.getElementById('video');
      const canvasElement = document.getElementById('canvas');
      canvasElement.width = videoElement.videoWidth;
      canvasElement.height = videoElement.videoHeight;
      const context = canvasElement.getContext('2d');
      // context.drawImage(videoElement, 0, 0, videoElement.videoWidth, videoElement.videoHeight);
      return canvasElement.toDataURL('image/png');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  initializeCamera();

  const captureButton = document.getElementById('capture');
  captureButton.addEventListener('click', async () => {
    const imageData = await captureImage();
    fetch('/save-image', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ image: imageData })
    })
    .then(response => response.json())
    .then(data => console.log(data))
    .catch(error => console.error('Error:', error));
  });
});
