package hotel;

import java.rmi.RemoteException;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

public class BookingManager implements BookingManagerInterface {

    private Room[] rooms;

    public BookingManager() throws RemoteException {
        this.rooms = initializeRooms();
    }

    public Set<Integer> getAllRooms() throws RemoteException {
        Set<Integer> allRooms = new HashSet<Integer>();
        Iterable<Room> roomIterator = Arrays.asList(rooms);
        for (Room room : roomIterator) {
            allRooms.add(room.getRoomNumber());
        }
        return allRooms;
    }

    public boolean isRoomAvailable(Integer roomNumber, LocalDate date) throws RemoteException {
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

    public void addBooking(BookingDetail bookingDetail) throws RemoteException {
        for (Room room : rooms) {
            if (room.getRoomNumber().equals(bookingDetail.getRoomNumber())) {
                room.getBookings().add(bookingDetail);
                return;
            }
        }
    }

    public Set<Integer> getAvailableRooms(LocalDate date) throws RemoteException {
        Set<Integer> availableRooms = new HashSet<Integer>();
        for (Room room : rooms) {
            if (isRoomAvailable(room.getRoomNumber(), date)) {
                availableRooms.add(room.getRoomNumber());
            }
        }
        return availableRooms;
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
