.pragma library

function stopAnimations(enterAnimation, exitAnimation) {
    enterAnimation.stop()
    exitAnimation.stop()
}

function applyRevealImmediately(surface, enterAnimation, exitAnimation) {
    stopAnimations(enterAnimation, exitAnimation)
    surface.waveProgress = 1
    surface.authOpacity = 1
}

function applyExitImmediately(surface, enterAnimation, exitAnimation) {
    stopAnimations(enterAnimation, exitAnimation)
    surface.waveProgress = 0
    surface.authOpacity = 0
}
