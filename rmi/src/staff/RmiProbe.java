package staff;

import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.time.LocalDate;
import java.util.Set;

import hotel.BookingDetail;
import hotel.BookingService;

public final class RmiProbe {

	private RmiProbe() {
	}

	public static void main(String[] args) throws Exception {
		String host = System.getenv().getOrDefault("RMI_HOST", "127.0.0.1");
		int port = Integer.parseInt(System.getenv().getOrDefault("RMI_REGISTRY_PORT", "1099"));
		String bindName = System.getenv().getOrDefault("RMI_BIND_NAME", "BookingService");
		LocalDate today = LocalDate.now();
		LocalDate tomorrow = today.plusDays(1);

		Registry registry = LocateRegistry.getRegistry(host, port);
		BookingService service = (BookingService) registry.lookup(bindName);

		System.out.println("RMI probe");
		System.out.println("  Host: " + host);
		System.out.println("  Port: " + port);
		System.out.println("  Binding: " + bindName);
		System.out.println("  Today: " + today);
		System.out.println("  Tomorrow: " + tomorrow);

		Set<Integer> allRooms = service.getAllRooms();
		System.out.println("getAllRooms -> " + allRooms);

		System.out.println("getAvailableRooms(today) before booking -> " + service.getAvailableRooms(today));
		System.out.println("isRoomAvailable(101, today) before booking -> " + service.isRoomAvailable(101, today));
		System.out.println("isRoomAvailable(999, today) unknown room -> " + service.isRoomAvailable(999, today));

		service.addBooking(new BookingDetail("probe-guest-1", 101, today));
		System.out.println("addBooking(101, today) -> OK");
		System.out.println("isRoomAvailable(101, today) after booking -> " + service.isRoomAvailable(101, today));
		System.out.println("getAvailableRooms(today) after booking -> " + service.getAvailableRooms(today));

		try {
			service.addBooking(new BookingDetail("probe-guest-duplicate", 101, today));
			System.out.println("addBooking(101, today) duplicate -> UNEXPECTED SUCCESS");
		} catch (Exception exception) {
			System.out.println("addBooking(101, today) duplicate -> EXPECTED FAILURE: "
				+ exception.getClass().getSimpleName() + ": " + exception.getMessage());
		}

		service.addBooking(new BookingDetail("probe-guest-2", 101, tomorrow));
		System.out.println("addBooking(101, tomorrow) -> OK");
		System.out.println("isRoomAvailable(101, tomorrow) after booking -> " + service.isRoomAvailable(101, tomorrow));
		System.out.println("getAvailableRooms(tomorrow) after booking -> " + service.getAvailableRooms(tomorrow));

		service.addBooking(new BookingDetail("probe-guest-3", 203, today));
		System.out.println("addBooking(203, today) -> OK");
		System.out.println("getAvailableRooms(today) final -> " + service.getAvailableRooms(today));
	}
}
