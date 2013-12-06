{-# LANGUAGE OverloadedStrings #-}

module Main where

-- General Haskell modules
import           Control.Monad (unless)
import qualified Data.ByteString as BS
import qualified Data.List as L
import qualified Data.Vector.Storable as V
import           System.Exit (exitFailure)
import           System.IO

-- Import all OpenGL libraries qualified, for pedagogical reasons
import qualified Graphics.Rendering.OpenGL as GL
import qualified Graphics.UI.GLFW as GLFW
import           Graphics.Rendering.OpenGL (($=))

-- Local modules
import qualified Util.GLFW as U

main :: IO ()
main = do
    -- GLFW code will be the same in all variants
    win <- U.initialize "My First Triangle"
    setGraphicDefaults
    (program, attrib) <- initResources
    U.mainLoop (draw program attrib win) win
    freeResources
    U.cleanup win

initResources :: IO (GL.Program, GL.AttribLocation)
initResources = do
    vs <- GL.createShader GL.VertexShader
    GL.shaderSourceBS vs $= vsSource
    GL.compileShader vs
    compileOK <- GL.get $ GL.compileStatus vs
    unless compileOK $ do
        hPutStrLn stderr "Error in vertex shader\n"
        -- Give a bit more error message than in the C++ version
        slog <- GL.get $ GL.shaderInfoLog vs
        putStrLn $ "Log:" ++ slog
        exitFailure

    -- Do it again for the fragment shader
    fs <- GL.createShader GL.FragmentShader
    GL.shaderSourceBS fs $= fsSource
    GL.compileShader fs
    compileOK <- GL.get $ GL.compileStatus fs
    unless compileOK $ do
        hPutStrLn stderr "Error in fragment shader\n"
        -- Give a bit more error message than in the C++ version
        slog <- GL.get $ GL.shaderInfoLog fs
        putStrLn $ "Log:" ++ slog
        exitFailure

    program <- GL.createProgram
    GL.attachShader program vs
    GL.attachShader program fs
    GL.attribLocation program "coord2d" $= GL.AttribLocation 0
    GL.linkProgram program
    linkOK <- GL.get $ GL.linkStatus program
    GL.validateProgram program
    status <- GL.get $ GL.validateStatus program
    unless (linkOK && status) $ do
        hPutStrLn stderr "GL.linkProgram error"
        exitFailure
    GL.currentProgram $= Just program

    attrs <- GL.get $ GL.activeAttribs program
    case L.find (\(_,_,n) -> n == "coord2d") attrs of
        Nothing -> do
            hPutStrLn stderr "Could not bind attribute coord2d"
            exitFailure
        Just (i,_,_) -> do
            putStrLn $ "coord2d is in location: " ++ show i
            return (program, GL.AttribLocation (fromIntegral i))

draw :: GL.Program -> GL.AttribLocation -> GLFW.Window -> IO ()
draw program _ win = do
    let attrib = GL.AttribLocation 0
    GL.clearColor $= GL.Color4 1 1 1 1
    GL.clear [GL.ColorBuffer, GL.DepthBuffer]
    -- In C++ example GLUT handles this?
    (width, height) <- GLFW.getFramebufferSize win
    GL.viewport $= (GL.Position 0 0, GL.Size (fromIntegral width) (fromIntegral height))
    GL.currentProgram $= Just program
    GL.get GL.errors >>= mapM_ (putStrLn . ("GL: "++) . show)
    GL.vertexAttribArray attrib $= GL.Enabled
    V.unsafeWith vertices $ \ptr ->
        GL.vertexAttribPointer attrib $=
          (GL.ToFloat, GL.VertexArrayDescriptor 2 GL.Float 0 ptr)
    GL.drawArrays GL.Triangles 0 3 -- 3 is the hardcoded number of vertices
    GL.vertexAttribArray attrib $= GL.Disabled

freeResources :: IO ()
freeResources = return ()

setGraphicDefaults :: IO ()
setGraphicDefaults = do
    GL.blend $= GL.Enabled
    GL.blendFunc $= (GL.SrcAlpha, GL.OneMinusSrcAlpha)
    GL.depthFunc $= Nothing

printGraphicStats :: IO ()
printGraphicStats = do
    -- Display some info about opengl
    vendorStr   <- GL.get GL.vendor
    rendererStr <- GL.get GL.renderer
    versionStr  <- GL.get GL.glVersion
    exts        <- GL.get GL.glExtensions
    glslV       <- GL.get GL.shadingLanguageVersion

    putStrLn $ L.intercalate "\n" [ "Vendor:" ++ vendorStr
                                   , "Renderer:" ++ rendererStr
                                   , "OpenGL Version:" ++ versionStr
                                   , "GLSL Version:" ++ glslV
                                   , "Extensions:\n  [ " ++ L.intercalate "\n  , " exts ++ "\n  ]"
                                   ]

vsSource, fsSource :: BS.ByteString
vsSource = BS.intercalate "\n"
           [
            "attribute vec2 coord2d; "
           , ""
           , "void main(void) { "
           , " gl_Position = vec4(coord2d, 0.0, 1.0); "
           , "}"
           ]

fsSource = BS.intercalate "\n"
           [
            ""
           , "void main(void) { "
           , " gl_FragColor[0] = 0.0; "
           , " gl_FragColor[1] = 0.0; "
           , " gl_FragColor[2] = 1.0; "
           , "}"
           ]

vertices :: V.Vector Float
vertices = V.fromList [  0.0,  0.8
                      , -0.8, -0.8
                      ,  0.8, -0.8
                      ]
