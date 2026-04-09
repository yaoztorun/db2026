package hotel;

import java.rmi.RemoteException;
import java.rmi.server.UnicastRemoteObject;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

public class BookingManager extends UnicastRemoteObject implements BookingService {

	private static final long serialVersionUID = 1L;

	private Room[] rooms;

	public BookingManager(int servicePort) throws RemoteException {
		super(servicePort);
		this.rooms = initializeRooms();
	}

	@Override
	public synchronized Set<Integer> getAllRooms() {
		Set<Integer> allRooms = new HashSet<Integer>();
		Iterable<Room> roomIterator = Arrays.asList(rooms);
		for (Room room : roomIterator) {
			allRooms.add(room.getRoomNumber());
		}
		return allRooms;
	}

	@Override
	public synchronized boolean isRoomAvailable(Integer roomNumber, LocalDate date) {
		for (Room room : rooms) {
			if (room.getRoomNumber().equals(roomNumber)) {
				for (BookingDetail booking : room.getBookings()) {
					if (booking.getDate().equals(date)) {
						return false;
					}
				}
				return true;
			}
		}
		return false;
	}

	@Override
	public synchronized void addBooking(BookingDetail bookingDetail) throws RemoteException {
		if (!isRoomAvailable(bookingDetail.getRoomNumber(), bookingDetail.getDate())) {
			throw new RemoteException(
				"Room " + bookingDetail.getRoomNumber() + " is not available on " + bookingDetail.getDate()
			);
		}
		for (Room room : rooms) {
			if (room.getRoomNumber().equals(bookingDetail.getRoomNumber())) {
				room.getBookings().add(bookingDetail);
				return;
			}
		}
	}

	@Override
	public synchronized Set<Integer> getAvailableRooms(LocalDate date) {
		Set<Integer> avaliableRooms = new HashSet<Integer>();
		for(Room room : rooms){
			if(isRoomAvailable(room.getRoomNumber(), date)){
				avaliableRooms.add(room.getRoomNumber());
			}
		}
		return avaliableRooms;
	}

	private static Room[] initializeRooms() {
		Room[] rooms = new Room[4];
		rooms[0] = new Room(101);
		rooms[1] = new Room(102);
		rooms[2] = new Room(201);
		rooms[3] = new Room(203);
		return rooms;
	}
}
