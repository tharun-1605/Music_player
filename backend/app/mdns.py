import socket
import logging
from zeroconf import Zeroconf, ServiceInfo

logger = logging.getLogger("uvicorn")

class MDNSService:
    def __init__(self, port: int = 8000):
        self.port = port
        self.zeroconf = None
        self.info = None

    def _get_primary_ip(self) -> str:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # Connecting to a dummy non-routable address to discover outward interface IP
            s.connect(("10.255.255.255", 1))
            ip = s.getsockname()[0]
        except Exception:
            ip = "127.0.0.1"
        finally:
            s.close()
        return ip

    def start(self):
        local_ip = self._get_primary_ip()
        try:
            self.zeroconf = Zeroconf()
            addresses = [socket.inet_aton(local_ip)] if local_ip != "127.0.0.1" else []
            self.info = ServiceInfo(
                type_="_lanmusic._tcp.local.",
                name="LAN Music Server._lanmusic._tcp.local.",
                addresses=addresses,
                port=self.port,
                properties={"app": "lanmusic", "version": "1.0.0"},
                server="lanmusic.local.",
            )
            self.zeroconf.register_service(self.info)
            logger.info(f"mDNS Service registered: lanmusic.local:{self.port} (Primary IP: {local_ip})")
        except Exception as e:
            logger.warning(f"mDNS broadcast notice: {e}")

    def stop(self):
        if self.zeroconf and self.info:
            try:
                self.zeroconf.unregister_service(self.info)
                self.zeroconf.close()
                logger.info("mDNS Service unregistered.")
            except Exception as e:
                logger.warning(f"Error stopping mDNS service: {e}")

mdns_instance = MDNSService()
