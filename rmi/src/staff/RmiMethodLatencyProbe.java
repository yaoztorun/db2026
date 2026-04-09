package staff;

import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.time.LocalDate;

import hotel.BookingDetail;
import hotel.BookingService;

public final class RmiMethodLatencyProbe {

	private RmiMethodLatencyProbe() {
	}

	private interface RemoteCall {
		void run() throws Exception;
	}

	private static double measureMs(RemoteCall call) throws Exception {
		long start = System.nanoTime();
		call.run();
		return (System.nanoTime() - start) / 1_000_000.0;
	}

	private static void printMetric(String method, int iteration, double latencyMs) {
		System.out.printf("%s,%d,%.3f%n", method, iteration, latencyMs);
	}

	public static void main(String[] args) throws Exception {
		String host = System.getenv().getOrDefault("RMI_HOST", "127.0.0.1");
		int port = Integer.parseInt(System.getenv().getOrDefault("RMI_REGISTRY_PORT", "1099"));
		String bindName = System.getenv().getOrDefault("RMI_BIND_NAME", "BookingService");
		int iterations = Integer.parseInt(System.getenv().getOrDefault("RMI_ITERATIONS", "20"));
		int bookingOffsetDays = Integer.parseInt(System.getenv().getOrDefault("RMI_BOOKING_OFFSET_DAYS", "1"));
		LocalDate today = LocalDate.now();
		LocalDate tomorrow = today.plusDays(1);

		Registry registry = LocateRegistry.getRegistry(host, port);
		BookingService service = (BookingService) registry.lookup(bindName);

		System.out.println("method,iteration,latency_ms");

		for (int i = 1; i <= iterations; i++) {
			printMetric("getAllRooms", i, measureMs(service::getAllRooms));
		}

		for (int i = 1; i <= iterations; i++) {
			printMetric("getAvailableRooms_today", i, measureMs(() -> service.getAvailableRooms(today)));
		}

		for (int i = 1; i <= iterations; i++) {
			printMetric("isRoomAvailable_201_today", i, measureMs(() -> service.isRoomAvailable(201, today)));
		}

		for (int i = 1; i <= iterations; i++) {
			final int bookingIndex = i;
			printMetric(
				"addBooking_unique_room102_future",
				i,
				measureMs(() -> service.addBooking(
					new BookingDetail("latency-probe-" + bookingIndex, 102, tomorrow.plusDays(bookingOffsetDays + bookingIndex))
				))
			);
		}
	}
}
