using UnityEditor;
using UnityEngine;
public sealed class WilliamArtImporter : AssetPostprocessor {
    void OnPreprocessTexture(){
        if(!assetPath.StartsWith("Assets/William/Resources/Art/"))return;
        var importer=(TextureImporter)assetImporter;
        importer.textureType=TextureImporterType.Default;
        importer.filterMode=FilterMode.Point;
        importer.mipmapEnabled=false;
        importer.alphaIsTransparency=true;
        importer.npotScale=TextureImporterNPOTScale.None;
        importer.maxTextureSize=8192;
        importer.textureCompression=TextureImporterCompression.Uncompressed;
    }
}
