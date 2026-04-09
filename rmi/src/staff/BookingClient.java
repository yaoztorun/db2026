package staff;

import java.rmi.registry.LocateRegistry;
import java.rmi.registry.Registry;
import java.time.LocalDate;
import java.util.Set;

import hotel.BookingDetail;
import hotel.BookingService;

public class BookingClient extends AbstractScriptedSimpleTest {

	private BookingService bm = null;

	public static void main(String[] args) throws Exception {
		BookingClient client = new BookingClient();
		client.run();
	}

	/***************
	 * CONSTRUCTOR *
	 ***************/
	public BookingClient() {
		try {
			String host = System.getenv().getOrDefault("RMI_HOST", "127.0.0.1");
			int port = Integer.parseInt(System.getenv().getOrDefault("RMI_REGISTRY_PORT", "1099"));
			String bindName = System.getenv().getOrDefault("RMI_BIND_NAME", "BookingService");
			Registry registry = LocateRegistry.getRegistry(host, port);
			bm = (BookingService) registry.lookup(bindName);
		} catch (Exception exp) {
			throw new IllegalStateException("Failed to connect to RMI registry", exp);
		}
	}

	@Override
	public boolean isRoomAvailable(Integer roomNumber, LocalDate date) throws Exception {
		return bm.isRoomAvailable(roomNumber, date);
	}

	@Override
	public void addBooking(BookingDetail bookingDetail) throws Exception {
		bm.addBooking(bookingDetail);
	}

	@Override
	public Set<Integer> getAvailableRooms(LocalDate date) throws Exception {
		return bm.getAvailableRooms(date);
	}

	@Override
	public Set<Integer> getAllRooms() throws Exception {
		return bm.getAllRooms();
	}
}
