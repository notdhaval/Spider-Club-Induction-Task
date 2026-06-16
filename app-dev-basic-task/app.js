// Global State Variables - tracking scores and game state
let currentRound = 1;
let userLives = 5;
let botLives = 5;
let userAlive = true;
let botAlive = true;
let previousTarget = 50; // default starting anchor for bot tracking

// DOM Nodes
const inputField = document.getElementById('txt-input');
const playBtn = document.getElementById('btn-play');
const restartBtn = document.getElementById('btn-restart');
const logScreen = document.getElementById('terminal-screen');

// Game Metrics Elements
const lblRound = document.getElementById('lbl-round');
const lblTarget = document.getElementById('lbl-target');
const lblWinner = document.getElementById('lbl-winner');

// Hearts/Cards Elements
const scoreUser = document.getElementById('score-user');
const scoreBot = document.getElementById('score-bot');
const cardUser = document.getElementById('card-user');
const cardBot = document.getElementById('card-bot');

// Play button trigger mechanisms
playBtn.addEventListener('click', handleTurn);
inputField.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') handleTurn();
});

restartBtn.addEventListener('click', function() {
    window.location.reload();
});

function handleTurn() {
    let userGuess = parseInt(inputField.value);

    // Form input baseline validation checks
    if (isNaN(userGuess) || userGuess < 0 || userGuess > 100) {
        alert("Enter a proper integer between 0 and 100.");
        return;
    }

    // Adaptive bot logical choice profile
    // It picks close to the previous target with a random drift factor
    let drift = Math.floor(Math.random() * 13) - 6; // random int from -6 to +6
    let botGuess = Math.round(previousTarget + drift);
    
    // Bounds guard safety limit check for bot choice
    if (botGuess < 0) botGuess = 0;
    if (botGuess > 100) botGuess = 100;

    // Game theory formulas execution
    let sum = userGuess + botGuess;
    let avg = sum / 2;
    let target = avg * 0.8;
    previousTarget = target; // caching for next turn calculations

    // Delta calculation paths (Absolute deviation check)
    let userDelta = Math.abs(userGuess - target);
    let botDelta = Math.abs(botGuess - target);

    let roundLog = document.createElement('div');
    roundLog.className = 'log-block';

    let logContent = `<strong>Round ${currentRound} Summary:</strong><br>`;
    logContent += `Your choice: ${userGuess} | Enemy choice: ${botGuess}<br>`;
    logContent += `Computed Target (Average * 0.8): <b>${target.toFixed(2)}</b><br>`;

    // Evaluate proximity and penalize the furthest entity
    if (userDelta > botDelta) {
        userLives--;
        logContent += `<span style="color: #e06c75;">Result: You were furthest from target! Lost 1 life.</span>`;
        lblWinner.innerText = "Enemy (Bot)";
    } else if (botDelta > userDelta) {
        botLives--;
        logContent += `<span style="color: #98c379;">Result: Enemy was furthest from target! Enemy lost 1 life.</span>`;
        lblWinner.innerText = "You (Player)";
    } else {
        logContent += `<span style="color: #d19a66;">Result: Absolute tie! No lives were lost this round.</span>`;
        lblWinner.innerText = "Tie Round";
    }

    // Committing updates back to View Layer UI elements
    lblTarget.innerText = target.toFixed(2);
    
    if (userLives <= 0) {
        userAlive = false;
        scoreUser.innerText = "ELIMINATED";
        cardUser.classList.add('dead');
    } else {
        scoreUser.innerText = "❤".repeat(userLives);
    }

    if (botLives <= 0) {
        botAlive = false;
        scoreBot.innerText = "ELIMINATED";
        cardBot.classList.add('dead');
    } else {
        scoreBot.innerText = "❤".repeat(botLives);
    }

    roundLog.innerHTML = logContent;
    logScreen.appendChild(roundLog);
    logScreen.scrollTop = logScreen.scrollHeight; // maintain scroll focus tracking

    // Evaluation check for terminating convergence triggers
    if (!userAlive || !botAlive) {
        endSession();
    } else {
        currentRound++;
        lblRound.innerText = currentRound;
        inputField.value = ''; // wipe field container clean
    }
}

function endSession() {
    inputField.disabled = true;
    playBtn.disabled = true;
    restartBtn.style.display = 'inline-block';

    let finalBanner = document.createElement('div');
    finalBanner.style.marginTop = '15px';
    finalBanner.style.fontWeight = 'bold';

    if (!userAlive && !botAlive) {
        finalBanner.innerHTML = "<span style='color: #d19a66;'>[MUTUAL ANNIHILATION] Both elements crashed out simultaneously.</span>";
    } else if (!userAlive) {
        finalBanner.innerHTML = "<span style='color: #e06c75;'>[SIMULATION TERMINATED] Game Over. You lost the match.</span>";
    } else {
        finalBanner.innerHTML = "<span style='color: #98c379;'>[VICTORY ACHIEVED] Simulation Complete. You are the sole survivor!</span>";
    }
    logScreen.appendChild(finalBanner);
    logScreen.scrollTop = logScreen.scrollHeight;
}

