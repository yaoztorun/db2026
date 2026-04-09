package staff;

import java.rmi.AlreadyBoundException;
import java.rmi.RemoteException;
import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;

import hotel.BookingManager;
import hotel.BookingService;

public final class BookingServer {

	private BookingServer() {
	}

	public static void main(String[] args) throws Exception {
		String bindName = System.getenv().getOrDefault("RMI_BIND_NAME", "BookingService");
		int registryPort = Integer.parseInt(System.getenv().getOrDefault("RMI_REGISTRY_PORT", "1099"));
		int servicePort = Integer.parseInt(System.getenv().getOrDefault("RMI_SERVICE_PORT", "1100"));

		System.setProperty(
			"java.rmi.server.hostname",
			System.getenv().getOrDefault("RMI_SERVER_HOSTNAME", "127.0.0.1")
		);

		Registry registry = ensureRegistry(registryPort);
		BookingService bookingService = new BookingManager(servicePort);

		try {
			registry.bind(bindName, bookingService);
		} catch (AlreadyBoundException alreadyBound) {
			registry.rebind(bindName, bookingService);
		}

		System.out.println(
			"RMI server ready on registry port " + registryPort
				+ ", service port " + servicePort
				+ " with binding '" + bindName + "'"
		);
		Thread.currentThread().join();
	}

	private static Registry ensureRegistry(int registryPort) throws RemoteException {
		try {
			Registry registry = LocateRegistry.getRegistry(registryPort);
			registry.list();
			return registry;
		} catch (RemoteException unavailableRegistry) {
			return LocateRegistry.createRegistry(registryPort);
		}
	}
}
