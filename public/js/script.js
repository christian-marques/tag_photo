let globalStream = null; // Stream global para garantir consistência

// Função para gerenciar a câmera
async function startCamera() {
    if (globalStream) {
        console.log("Câmera já está ativa");
        return;
    }
    try {
        globalStream = await navigator.mediaDevices.getUserMedia({ video: true });
        const videoElement = document.getElementById('video');
        videoElement.srcObject = globalStream;
        videoElement.play();
        console.log("Câmera iniciada");
    } catch (error) {
        console.error("Erro ao acessar a câmera:", error);
    }
}

// Função para parar a câmera
function stopCamera() {
    if (!globalStream) {
        console.log("Não há câmera ativa para desligar");
        return;
    }
    globalStream.getTracks().forEach(track => {
        track.stop();
    });
    const videoElement = document.getElementById('video');
    videoElement.srcObject = null;
    globalStream = null;
    console.log("Câmera desligada");
}


// Função para capturar imagem
async function captureImage() {
  if (!globalStream) {
      console.log("Câmera não está ativa");
      return;
  }
  const videoElement = document.getElementById('video');
  const canvasElement = document.createElement('canvas'); // Cria um canvas temporário
  canvasElement.width = videoElement.videoWidth;
  canvasElement.height = videoElement.videoHeight;
  const context = canvasElement.getContext('2d');
  context.drawImage(videoElement, 0, 0, canvasElement.width, canvasElement.height);
  return canvasElement.toDataURL('image/png'); // Retorna a imagem como Data URL
}

document.addEventListener('DOMContentLoaded', () => {
    const toggleButton = document.getElementById('toggle');
    const captureButton = document.getElementById('capture');

    
    captureButton.addEventListener('click', async () => {
      const imageData = await captureImage();
      if (!imageData) {
          console.log("Nenhuma imagem para enviar");
          return;
      }
      fetch('/save-image', {
          method: 'POST',
          headers: {
              'Content-Type': 'application/json'
          },
          body: JSON.stringify({ image: imageData })
      })
      .then(response => response.json())
      .then(data => console.log("Imagem enviada com sucesso:", data))
      .catch(error => console.error('Erro ao enviar imagem:', error));
    });

    toggleButton.addEventListener('click', () => {
        if (globalStream) {
            stopCamera();
        } else {
            startCamera();
        }
    });

    // Inicializa a câmera ao carregar a página
    startCamera();
});
