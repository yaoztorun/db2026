package staff;

import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.time.LocalDate;

import hotel.BookingService;

public final class RmiLoadClient {

	private RmiLoadClient() {
	}

	public static void main(String[] args) throws Exception {
		String host = System.getenv().getOrDefault("RMI_HOST", "127.0.0.1");
		int port = Integer.parseInt(System.getenv().getOrDefault("RMI_REGISTRY_PORT", "1099"));
		String bindName = System.getenv().getOrDefault("RMI_BIND_NAME", "BookingService");
		int requests = Integer.parseInt(System.getenv().getOrDefault("RMI_REQUESTS", "1"));

		Registry registry = LocateRegistry.getRegistry(host, port);
		BookingService bookingService = (BookingService) registry.lookup(bindName);
		LocalDate targetDate = LocalDate.now();

		for (int i = 0; i < requests; i++) {
			long start = System.nanoTime();
			String errorType = "";
			int ok = 1;

			try {
				bookingService.getAvailableRooms(targetDate);
			} catch (Exception exception) {
				ok = 0;
				errorType = exception.getClass().getSimpleName();
			}

			double latencyMs = (System.nanoTime() - start) / 1_000_000.0;
			System.out.printf("%.3f,%d,%s%n", latencyMs, ok, errorType);
		}
	}
}
