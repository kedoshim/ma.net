// ==========================
// controller.js
// ==========================

// Status
const connection_status = document.getElementById('status');

// Conexão WebSocket
const wsUrl = `ws://${location.hostname}:8000/ws`;
let ws = new WebSocket(wsUrl);

ws.onopen = () => connection_status.innerText = 'Connectado';
ws.onclose = () => connection_status.innerText = 'Desconectado';
ws.onerror = () => connection_status.innerText = 'Error';
const playerStatus = document.getElementById('player-status');

ws.onmessage = (m) => {
    try {
        const d = JSON.parse(m.data);
        console.log(d);

        if (d.type === 'assigned') {
            const roman = toRoman(d.slot + 1);
            connection_status.innerText = 'Player ' + roman;
        }

        if (d.type === 'toggle_btn' && d.btn) {
            const btnId = 'btn' + d.btn.toUpperCase();
            setButtonVisible(btnId, d.visible !== false); // show if true or undefined, hide if false
        }
    } catch (e) {}
};

// Helper function to convert numbers 1–10 (or more) to Roman numerals
function toRoman(num) {
    const romans = [
        '', 'I', 'II', 'III', 'IV', 'V',
        'VI', 'VII', 'VIII', 'IX', 'X',
        'XI', 'XII', 'XIII', 'XIV', 'XV',
    ];
    return romans[num] || num; // fallback if out of range
}



function send(obj) {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(obj));
    }
}

// ==========================
// Joystick
// ==========================
const joy = document.getElementById('joy');
const stick = document.getElementById('stick');
let active = false, rect = null, center = {x:0, y:0};

function startStick(e) {
    active = true;
    rect = joy.getBoundingClientRect();
    center = {x: rect.width/2, y: rect.height/2};
    moveStick(e);
}

function moveStick(e) {
    if (!active) return;
    let touch = e.touches ? e.touches[0] : e;
    let x = touch.clientX - rect.left;
    let y = touch.clientY - rect.top;

    let nx = (x - center.x) / (rect.width/2);
    let ny = (y - center.y) / (rect.height/2);
    nx = Math.max(-1, Math.min(1, nx));
    ny = Math.max(-1, Math.min(1, ny));

    stick.style.left = (x - stick.offsetWidth/2) + 'px';
    stick.style.top = (y - stick.offsetHeight/2) + 'px';

    send({type:'stick', x: nx, y: -ny}); // inverter Y
    e.preventDefault();
}

function endStick(e) {
    active = false;
    stick.style.left = (center.x - stick.offsetWidth/2) + 'px';
    stick.style.top = (center.y - stick.offsetHeight/2) + 'px';
    send({type:'stick', x: 0, y: 0});
}

// Eventos Joystick
joy.addEventListener('touchstart', startStick);
joy.addEventListener('touchmove', moveStick);
joy.addEventListener('touchend', endStick);
joy.addEventListener('mousedown', startStick);
window.addEventListener('mousemove', moveStick);
window.addEventListener('mouseup', endStick);

// ==========================
// Botões A, B e Start (XInput)
// ==========================
function wireBtn(id, xinputId){
    const b = document.getElementById(id);
    if (!b) return;
    b.addEventListener('touchstart', e => { send({type:'button', id:xinputId, state:'down'});});
    b.addEventListener('touchend', e => { send({type:'button', id:xinputId, state:'up'});});
    b.addEventListener('mousedown', e => { send({type:'button', id:xinputId, state:'down'}); });
    b.addEventListener('mouseup', e => { send({type:'button', id:xinputId, state:'up'}); });
}

wireBtn('btnA', 'A');       // XInput A
wireBtn('btnB', 'B');       // XInput B
wireBtn('btnX', 'X');       // XInput B
wireBtn('btnY', 'Y');       // XInput B
wireBtn('btnStart', 'START'); // XInput Start
wireBtn('btnSelect', 'SELECT'); // XInput Start

// ==========================
// D-Pad (XInput)
// ==========================
const dpadButtons = ['up','down','left','right'];

dpadButtons.forEach(dir => {
    const btn = document.getElementById('dpad-'+dir);
    const xinputId = dir.toUpperCase();
    btn.addEventListener('touchstart', e => { send({type:'button', id:xinputId, state:'down'});});
    btn.addEventListener('touchend', e => { send({type:'button', id:xinputId, state:'up'});});
    btn.addEventListener('mousedown', e => { send({type:'button', id:xinputId, state:'down'}); });
    btn.addEventListener('mouseup', e => { send({type:'button', id:xinputId, state:'up'}); });
});

// ==========================
// Toggle Joystick / D-Pad
// ==========================
const toggleInput = document.getElementById('modeSwitch'); // input type=checkbox

// estado inicial
joy.style.display = 'block';
dpad.style.display = 'none';

toggleInput.addEventListener('change', () => {
    if (toggleInput.checked) {
        joy.style.display = 'none';
        dpad.style.display = 'grid';
    } else {
        joy.style.display = 'block';
        dpad.style.display = 'none';
    }
});


// ==========================
// Função para mostrar/ocultar botões (DOM removal/add)
// ==========================
function setButtonVisible(btnId, visible) {
    const btn = document.getElementById(btnId);
    const buttonsGrid = document.getElementById('buttons');
    if (!btn || !buttonsGrid) return;
    if (visible) {
        // If not present, re-add in correct order
        if (!buttonsGrid.contains(btn)) {
            // Find correct position by id order
            const order = ['btnY', 'btnB', 'btnX', 'btnA'];
            let inserted = false;
            for (let i = 0; i < order.length; i++) {
                if (order[i] === btnId) {
                    // Insert before the next present button
                    for (let j = i + 1; j < order.length; j++) {
                        const nextBtn = document.getElementById(order[j]);
                        if (nextBtn && buttonsGrid.contains(nextBtn)) {
                            buttonsGrid.insertBefore(btn, nextBtn);
                            inserted = true;
                            break;
                        }
                    }
                    if (!inserted) buttonsGrid.appendChild(btn);
                    break;
                }
            }
        }
    } else {
        // Remove from grid
        if (buttonsGrid.contains(btn)) {
            buttonsGrid.removeChild(btn);
        }
    }
}
