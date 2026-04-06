import qrcode
from qrcode.image.styledpil import StyledPilImage
from qrcode.image.styles.moduledrawers import RoundedModuleDrawer
from qrcode.image.styles.colormasks import SolidFillColorMask # <-- Import this

def generate_qr_code_image(url: str):
    
    qr = qrcode.QRCode(
        version=1,
        box_size=10,
        border=4
    )

    qr.add_data(url)
    qr.make(fit=True)

    img = qr.make_image(
        image_factory=StyledPilImage,
        module_drawer=RoundedModuleDrawer(),
        # Use an RGBA color mask instead of string kwargs
        color_mask=SolidFillColorMask(
            back_color=(255, 255, 255, 0), # White with 0 Alpha = Transparent
            front_color=(0, 0, 0, 255)     # Black with 255 Alpha = Solid
        )
    )

    return img