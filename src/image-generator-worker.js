const {createCanvas, loadImage} = require('canvas')
const fs = require('node:fs/promises')

let running = true;
let busy = false;
process.on('message', async (msg) => {
  if (busy) {
    process.send({ id, error: 'busy' });
    return;
  }
  
  if (msg === 'exit') {
    process.exit(0);
  }
  
  const { id, config, combo } = msg;
  try {
    busy = true;
    const canvas = await createCanvas(...config.imageSize);
    const ctx = canvas.getContext('2d');
    
    for (const attr of combo) {
      const img = await loadImage(Buffer.from(attr.image, 'base64'))
      ctx.drawImage(img, ...attr.layer.position, ...attr.layer.size);
    }
    
    const buffer = canvas.toBuffer('image/png');
    const filename = getFilename(config, id);
    await fs.writeFile(filename, buffer);
    process.send({ id, filename });
  } catch (error) {
    process.send({ id, error: { msg: error.message, stack: error.stack } });
  } finally {
    busy = false;
  }
});

const getFilename = (config, id) => `${config.out}/${config.filenameTemplate}.png`.replace('{}', id);
